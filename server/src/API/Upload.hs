{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Codec.Archive.Zip qualified as ZIP
import Codec.Compression.Zlib qualified as Zlib
import Config (AppConfig, Config (dataDir))
import Control.Monad
import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.ByteString.Lazy qualified as LBS
import Data.Kind (Type)
import Data.Map qualified as M
import Data.Text (Text)
import Data.Time.Clock.POSIX
import GHC.Generics (Generic)
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (renameFile)

type UploadRoutes :: Type -> Type
data UploadRoutes route = MkUploadRoutes
  { _log :: route :- "report" :> MultipartForm Tmp Report :> Post '[JSON] Integer
  }
  deriving stock (Generic)

data Report = MkReport {report :: FilePath, fileName :: Text} deriving stock (Show)
instance FromMultipart Tmp Report where
  fromMultipart multipartData =
    MkReport <$> fmap fdPayload (lookupFile "report" multipartData) <*> fmap fdFileName (lookupFile "report" multipartData)

upload :: (?config :: Config) => Report -> Handler Integer
-- upload ::(AppConfig) =>  Report -> Handler Integer
upload r = do
  let c = ?config
  liftIO $ do
    tm <- getPOSIXTime
    let dataPath = c.dataDir
        tmStr = show tm
        filePath = dataPath <> tmStr

    renameFile (r.report) filePath
    en <- ZIP.withArchive filePath (ZIP.unpackInto dataPath)
    entries <- ZIP.withArchive filePath (M.keys <$> ZIP.getEntries)
    
    print r

  -- cmp <- liftIO $ LBS.readFile newPath

  -- void $ liftIO $ LBS.writeFile jsonFilePath $ Zlib.decompress cmp

  return 0

uploadHandlers :: (AppConfig) => UploadRoutes AsServer
-- uploadHandlers ::(?config::Config) =>  UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { _log = upload
    }
