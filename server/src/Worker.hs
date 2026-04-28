{-# LANGUAGE OverloadedStrings #-}

module Worker
  ( Job (..)
  , JobResult (..)
  , WorkerConfig (..)
  , defaultWorkerConfig
  , startWorker
  , startWorkers
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (Async, async, link)
import Control.Exception (SomeException, try)
import Control.Monad (forever)
import Data.Text qualified as T
import Log (runLogT)
import Relago.Prelude

data JobResult
  = JobSuccess Text
  | JobFailure Text
  deriving stock (Eq, Show)

data Job = MkJob
  { jName :: Text
  , jInterval :: Int -- Interval in seconds
  , jAction :: IO JobResult
  }

data WorkerConfig = WorkerConfig
  { wRetryOnFailure :: Bool
  , wMaxRetries :: Int
  }
  deriving stock (Eq, Show)

defaultWorkerConfig :: WorkerConfig
defaultWorkerConfig =
  WorkerConfig
    { wRetryOnFailure = True
    , wMaxRetries = 3
    }

startWorker :: (AppState) => WorkerConfig -> Job -> IO (Async ())
startWorker config job = do
  a <- async $ runWorker config job
  link a
  pure a

startWorkers :: (AppState) => WorkerConfig -> [Job] -> IO [Async ()]
startWorkers config = mapM (startWorker config)

runWorker :: (AppState) => WorkerConfig -> Job -> IO ()
runWorker _config job = forever $ do
  let logLevel = envLogLevel ?st.config.environment
  runLogT ("worker:" <> job.jName) ?st.logger logLevel do
    logTrace_ $ "Running job: " <> job.jName

    result <- liftIO $ try @SomeException job.jAction
    case result of
      Left err ->
        logAttention_ $ "Error: " <> T.pack (show err)
      Right (JobSuccess msg) ->
        logInfo_ $ "Success: " <> msg
      Right (JobFailure msg) ->
        logAttention_ $ "Failed: " <> msg

  threadDelay (job.jInterval * 1_000_000)
