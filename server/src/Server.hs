{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

module Server where

import API
import Config
import Network.Wai.Handler.Warp qualified as WP
import Toml.Schema.Matcher (Result (..))

run :: IO ()
run = do
  putStrLn "Application ready to start"
  cn <- loadConfig "../config.toml" -- FIXME: generate config file with nix
  case cn of
    Success _ c -> do
      let ?config = c
      WP.run c.port $ runApi
    Failure _ -> print "error"

-- FIXME: port number from options
