{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Codec.Compression.Zlib qualified as Zlib
import Control.Monad
import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.ByteString.Lazy qualified as LBS
import Data.Kind (Type)
import GHC.Generics (Generic)
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (renameFile)
import Codec.Archive.Zip qualified as ZIP
import Data.Time.Clock.POSIX
import  Data.Map qualified as M

type UploadRoutes :: Type -> Type
data UploadRoutes route = MkUploadRoutes
  { _log :: route :- "report" :> MultipartForm Tmp Report :> Post '[JSON] Integer
  }
  deriving stock (Generic)

data Report = MkReport { fileName:: Text report :: FilePath } deriving stock (Show)
instance FromMultipart Tmp Report where
  fromMultipart multipartData = MkReport <$> fmap fdPayload (lookupFile "report" multipartData)

upload :: Report -> Handler Integer
upload r = do
  liftIO $ do
    tm <- getPOSIXTime
    let dataPath = "/home/lambdajon/workspace/xinux/relago-support/data/"
        tmStr = show tm
        filePath = dataPath <> tmStr

    renameFile (r.report) filePath
    en <- ZIP.withArchive filePath (ZIP.unpackInto dataPath)
    entries <- ZIP.withArchive filePath (M.keys <$> ZIP.getEntries)

    print r.report

  -- cmp <- liftIO $ LBS.readFile newPath

  -- void $ liftIO $ LBS.writeFile jsonFilePath $ Zlib.decompress cmp

  return 0

uploadHandlers :: UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { _log = upload
    }
