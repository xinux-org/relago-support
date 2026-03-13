{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Server where

import API
import Network.Wai.Handler.Warp qualified as WP

run :: IO ()
run = do
  putStrLn "Application ready to start"
  -- FIXME: port number from options
  WP.run 4242 $ runApi
