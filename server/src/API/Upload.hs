{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Codec.Archive.Zip qualified as ZIP
import Codec.Compression.Zlib qualified as Zlib
import Config (AppConfig, Config (dataDir))
import Control.Monad
import Control.Monad.IO.Class (MonadIO (..))
import Data.ByteString.Lazy qualified as LBS
import Data.Kind (Type)
import Data.List (find)
import Data.Map qualified as M
import Data.Text (Text)
import Data.Time.Clock.POSIX
import GHC.Generics (Generic)
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (renameFile)
import System.FilePath
  ( addExtension
  , dropExtension
  , isExtensionOf
  , (</>)
  )

type UploadRoutes :: Type -> Type
newtype UploadRoutes route = MkUploadRoutes
  { _log :: route :- "report" :> MultipartForm Tmp Report :> Post '[JSON] Integer
  }
  deriving stock (Generic)

type Report :: Type
data Report = MkReport {report :: !FilePath, fileName :: !Text} deriving stock (Show)
instance FromMultipart Tmp Report where
  fromMultipart multipartData =
    MkReport <$> fmap fdPayload (lookupFile "report" multipartData) <*> fmap fdFileName (lookupFile "report" multipartData)

upload :: (?config :: Config) => Report -> Handler Integer
upload r = do
  let c = ?config
  liftIO $ do
    tm <- getPOSIXTime
    let dataPath = c.dataDir
        archiveFileName = show tm
        archiveFile = addExtension archiveFileName "zip"
        filePath = dataPath </> archiveFile
        unzipFolder = dataPath </> archiveFileName

    renameFile r.report filePath
    void $ ZIP.withArchive filePath (ZIP.unpackInto unzipFolder)
    entries <- ZIP.withArchive filePath (M.keys <$> ZIP.getEntries)

    let jr = find (isExtensionOf "zlib") $ fmap ZIP.unEntrySelector entries
    case jr of
      Just j -> do
        let fname = dropExtension j
        cmp <- LBS.readFile $ unzipFolder </> j
        LBS.writeFile (unzipFolder </> fname) $ Zlib.decompress cmp
      Nothing -> print "Journal not found" -- FIXME: Handle error
    print r
  return 0

uploadHandlers :: (AppConfig) => UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { _log = upload
    }
