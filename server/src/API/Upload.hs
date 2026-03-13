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
  liftIO $ do
    print r
  return 0

uploadHandlers :: UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { _log = upload
    }
