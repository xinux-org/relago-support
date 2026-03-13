{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Data.Aeson (FromJSON, ToJSON)
import Data.Kind (Type)
import GHC.Generics (Generic)
import Servant hiding (Param)
import Servant.Server.Generic (AsServer)

import Servant.Multipart
import Control.Monad.IO.Class (MonadIO(..))
import Control.Monad

type UploadRoutes :: Type -> Type
data UploadRoutes route = MkUploadRoutes
  { _log :: route :- "log" :> MultipartForm Tmp (MultipartData Tmp) :> Post '[JSON] Integer
  }
  deriving stock (Generic)

upload :: (MonadIO m, Num b) => MultipartData tag -> m b
upload multipartData = do
  liftIO $ do
    putStrLn "Inputs:"
    forM_ (inputs multipartData) $ \input ->
      print input
    forM_ (files multipartData) $ \file -> do
      -- let content = fdPayload file
      putStrLn $ "Content of " ++ show (fdFileName file)
    --   LBS.putStr content
  return 0

uploadHandlers :: UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { _log = upload
    }
