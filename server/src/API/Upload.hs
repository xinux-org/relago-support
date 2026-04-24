{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Codec.Archive.Zip qualified as ZIP
import Codec.Compression.Zlib qualified as Zlib
import Control.Monad (void, when)
import Data.ByteString.Lazy qualified as LBS
import Data.List (find)
import Data.Map qualified as M
import Data.Maybe (isNothing)
import Data.Text qualified as T
import Data.Time.Clock.POSIX (getPOSIXTime)
import Data.UUID (UUID)
import Database.Reports (createReport, getReporterById)
import Relago.Prelude
import Search.Reports
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (renameFile)
import System.FilePath (addExtension, dropExtension, dropFileName, isExtensionOf, (</>))
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
  reporter <- liftIO $ getReporterById uuid
  case reporter of
    Just rep -> do
      liftIO $ do
          
        print reporter
        tm <- getPOSIXTime -- FIXME: Use something unique identificator generator for rename archive file
        let dataPath = c.dataDir
            archiveFileName = show tm
            archiveFile = addExtension archiveFileName "zip"
            filePath = dataPath </> archiveFile
            unzipFolder = dataPath </> archiveFileName

        renameFile r.report filePath
        void $ ZIP.withArchive filePath (ZIP.unpackInto unzipFolder) -- Unpack zip archive
        entries <- ZIP.withArchive filePath (M.keys <$> ZIP.getEntries)

        let jr = find (isExtensionOf "zlib") $ ZIP.unEntrySelector <$> entries
        case jr of -- FIXME: simlify code
          Just j -> do
            let fname = dropExtension j
                iName = takeDirectory fname
                fpath = unzipFolder </> fname
            cmp <- LBS.readFile $ unzipFolder </> j
            pure ()
          -- LBS.writeFile fpath $ Zlib.decompress cmp
          -- void $ createReport (T.pack fname) (T.pack fpath)
          -- liftIO $ indexJournalLogsFromFile c.openSearch (T.pack iName) fpath
          Nothing -> print "Journal not found" -- FIXME: Handle error
        print r
    Nothing -> throwError $ err400{errBody = "No reporter"}
  return 0

uploadHandlers :: (AppState) => UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { -- _log = test1
      _log = upload
    }

-- test1 = undefined
