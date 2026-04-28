{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Codec.Archive.Zip qualified as ZIP
import Codec.Compression.Zlib qualified as Zlib
import Config (S3Config (..))
import Control.Monad (void)
import Crypto.Gpgme
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.List (find)
import Data.Map qualified as M
import Data.String (fromString)
import Data.Text qualified as T
import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.UUID (UUID)
import Data.UUID qualified as UUID
import Database.Reports (createReport, getReporterById)
import Database.Types (Reporter (..))
import Relago.Prelude
import S3 (UploadObject (..), downloadObject, uploadObjects)
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (createDirectoryIfMissing, renameFile)
import System.FilePath (addExtension, dropExtension, isExtensionOf, (</>))
import System.FilePath.Posix (takeDirectory)

type ReporterID = Header' '[Required, Strict] "Reporter-ID" UUID

type UploadRoutes :: Type -> Type
newtype UploadRoutes route = MkUploadRoutes
  { _log :: route :- "report" :> ReporterID :> MultipartForm Tmp Report :> Post '[JSON] Integer
  }
  deriving stock (Generic)

type Report :: Type
data Report = MkReport {report :: !FilePath, fileName :: !Text} deriving stock (Show)
instance FromMultipart Tmp Report where
  fromMultipart multipartData =
    let f = lookupFile "report" multipartData in (MkReport . fdPayload <$> f) <*> (fdFileName <$> f)

upload :: (AppState) => UUID -> Report -> Handler Integer
upload uuid r = do
  let c = ?st.config
      s3Con = ?st.s3Con
      s3Cfg = c.s3
      bucket = s3Cfg.s3MainBucket
  reporter <- liftIO $ getReporterById uuid

  case reporter of
    Just rep -> do
      secretKeyResult <- liftIO $ downloadObject s3Con bucket (T.pack rep.secretKey)
      case secretKeyResult of
        Left err -> throwError $ err400{errBody = "Wrong request" <> fromString (show err)} -- download key failed
        Right secretKeyData -> liftIO $ do
          tm <- getPOSIXTime
          let dataPath = c.dataDir
              keysDir = dataPath </> "tmp"
              archiveFileName = show tm
              archiveFile = addExtension archiveFileName "zip"
              filePath = dataPath </> archiveFile
              unzipFolder = dataPath </> archiveFileName
              scKeyPath = keysDir </> (archiveFileName <> "secret.asc")

          createDirectoryIfMissing True keysDir
          BS.writeFile scKeyPath secretKeyData

          dcRes <- withCtx keysDir "C" OpenPGP $ \ctx -> do
            importResult <- importKeyFromFile ctx scKeyPath
            print $ "Key imported: " <> show importResult

            let passCb _ _ _ = pure $ Just $ T.unpack rep.keyPass
            setPassphraseCallback ctx (Just passCb)

            encryptedData <- BS.readFile r.report

            decrypt ctx encryptedData

          case dcRes of
            Left err -> print $ "Decryption failed: " <> show err
            Right dt -> do
              -- Write decrypted zip file
              BS.writeFile filePath dt
              void $ ZIP.withArchive filePath (ZIP.unpackInto unzipFolder)
              entries <- ZIP.withArchive filePath (M.keys <$> ZIP.getEntries)

              let jr = find (isExtensionOf "zlib") $ ZIP.unEntrySelector <$> entries
              case jr of -- FIXME: simlify code
                Just j -> do
                  let fname = dropExtension j
                      iName = takeDirectory fname
                      fpath = unzipFolder </> fname
                      baseName = UUID.toString uuid </> iName
                      journalReportFile = "journal_report.json"
                      systemInfoFile = "system_info.json"
                      journalReportObj =
                        UploadObject (unzipFolder </> iName </> journalReportFile) (T.pack $ baseName </> journalReportFile)
                      systemInfoObj =
                        UploadObject (unzipFolder </> iName </> systemInfoFile) (T.pack $ baseName </> systemInfoFile)

                  cmp <- LBS.readFile $ unzipFolder </> j
                  LBS.writeFile fpath $ Zlib.decompress cmp
                  void $ createReport (T.pack journalReportFile) (T.pack baseName)

                  uploadObjects s3Con bucket [journalReportObj, systemInfoObj]
                Nothing -> print "Journal not found"
          print r
    Nothing -> throwError $ err400{errBody = "No reporter"}
  return 0

uploadHandlers :: (AppState) => UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { -- _log = test1
      _log = upload
    }
