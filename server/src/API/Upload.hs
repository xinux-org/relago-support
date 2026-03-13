{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Control.Monad
import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Kind (Type)
import GHC.Generics (Generic)
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (renameFile)
import System.FilePath ((</>))
import System.FS.IO.Unix (open, getSize, close)
import System.FS.API ( OpenMode() )
-- import System
-- import System.FS.IO.Unix(open, getSize, FHandle )
-- import System.FS.API (OpenMode(..), AllowExisting (..))
-- import System.FS.IO.Handle(HandleOS)
-- import Data.Coerce (coerce)
-- import System.Unsafe ()
import System.IO (openFile, IOMode(..))
import System.IO qualified as SIO hiding (ReadMode)

type UploadRoutes :: Type -> Type
data UploadRoutes route = MkUploadRoutes
  { _log :: route :- "report" :> MultipartForm Tmp Report :> Post '[JSON] Integer
  }
  deriving stock (Generic)

data Report = MkReport {logs :: FilePath} deriving stock (Show)
instance FromMultipart Tmp Report where
  fromMultipart multipartData = MkReport <$> fmap fdPayload (lookupFile "logs" multipartData)


upload :: Report -> Handler Integer
upload r = do
  -- we can access r.logs
  let newPath = "/home/lambdajon/workspace/xinux/relago-support/server/data/archive.zlib"

  -- let re = open r.logs ReadMode
  -- fd <- liftIO$ open r.logs (ReadWriteMode MustExist)
  -- fd <- liftIO$ open r.logs (ReadMode)

  -- sz <- liftIO $ getSize $ fd
  liftIO $ do
    -- renameFile (r.logs) newPath
    print r

  return 0

uploadHandlers :: UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { _log = upload
    }



