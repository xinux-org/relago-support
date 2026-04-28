{-# LANGUAGE DerivingVia #-}

module Server where

import API (runApi)
import Config (loadConfig)
import Control.Monad.Logger qualified as ML
import Data.Text.Encoding qualified as T
import Data.Text qualified as T
import Database (migrate')
import Database.Persist.Postgresql (createPostgresqlPool)
import Log (runLogT)
import Log.Backend.StandardOutput (withStdOutLogger)
import Network.Wai.Handler.Warp (defaultSettings, runSettings, setHost, setPort)
import Options.Generic
import Relago.Prelude
import S3 (s3Conn)
import Toml (prettyDecodeError)
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

  cn <- loadConfig op.cfg
  case cn of
    Success _ c -> withStdOutLogger \stdoutLogger -> do
      let logLevel = envLogLevel c.environment
      runLogT "relago-server" stdoutLogger logLevel do
        logInfo_ "Application starting..."

        pool <-
          liftIO
            $ ML.runStdoutLoggingT
            $ createPostgresqlPool (T.encodeUtf8 c.database) c.databasePoolSize

        let ?st = MkAppSt{config = c, db = pool, s3Con = s3Conn c.s3, logger = stdoutLogger}
        let settings = setPort c.port $ setHost "*" defaultSettings

        liftIO migrate'
        logInfo_ $ "Server listening on port " <> T.pack (show c.port)
        liftIO $ runSettings settings runApi
    Failure errs -> mapM_ (print . prettyDecodeError) errs
