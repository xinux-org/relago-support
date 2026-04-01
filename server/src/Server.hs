{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Server where

import API
import Config
import Data.Kind (Type)
import Network.Wai.Handler.Warp qualified as WP
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
      let ?config = c
      WP.run c.port $ runApi
    Failure _ -> print "error"

-- FIXME: port number from options
