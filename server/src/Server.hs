{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Server where

import API
import Config
import State (AppSt (..))
import Data.Kind (Type)
import Network.Wai.Handler.Warp qualified as WP
import Options.Generic
import Toml.Schema.Matcher (Result (..))
import Network.Wai.Handler.Warp
import Database.Persist.Postgresql (createPostgresqlPool)
import Control.Monad.Logger (runStdoutLoggingT)
import Data.Text.Encoding (encodeUtf8)

type Options :: Type -> Type
newtype Options w = Options
  { cfg :: w ::: FilePath <?> "Config file path" <#> "c"
  }
  deriving stock (Generic)

deriving anyclass instance ParseRecord (Options Wrapped)
deriving stock instance Show (Options Unwrapped)

run :: IO ()
run = do
  (op :: Options Unwrapped) <- unwrapRecord "Registrar application"
  putStrLn "Application ready to start"


  cn <- loadConfig op.cfg
  case cn of
    Success _ c -> do
      pool <- runStdoutLoggingT $
        createPostgresqlPool (encodeUtf8 c.database) c.databasePoolSize
      let ?st = MkAppSt { config = c, db = pool }
      let settings = setPort c.port $ setHost "*" defaultSettings

      WP.runSettings settings $ runApi
    Failure _ -> print "error"
