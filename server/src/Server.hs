{-# LANGUAGE DerivingVia #-}

module Server where

import Relago.Prelude

import API (runApi)
import Config (loadConfig)
import Control.Monad.Logger (runStdoutLoggingT)
import Database.Persist.Postgresql (createPostgresqlPool)
import Data.Text.Encoding (encodeUtf8)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import Options.Generic
import Toml.Schema.Matcher (Result (..))

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

      runSettings settings runApi
    Failure _ -> print "error"
