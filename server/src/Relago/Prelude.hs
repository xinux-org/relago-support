module Relago.Prelude
  ( Type
  , Constraint
  , Generic
  , Text
  , MonadIO (..)
  , ToJSON
  , FromJSON
  -- Application
  , AppState
  , AppSt (..)
  , Config (..)
  , Environment (..)
  , envLogLevel
  , Logger
  , LogLevel (..)
  , MonadLog
  , logInfo_
  , logAttention_
  , logTrace_
  , logInfo
  , logAttention
  , logTrace
  , localDomain
  , localData
  , object
  , (.=)
  ) where

import Config (Config (..), Environment (..), envLogLevel)
import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (FromJSON, ToJSON, object, (.=))
import Data.Kind (Constraint, Type)
import Data.Text (Text)
import GHC.Generics (Generic)
import Log (LogLevel (..), Logger, localData, localDomain)
import Log.Class
  ( MonadLog
  , logAttention
  , logAttention_
  , logInfo
  , logInfo_
  , logTrace
  , logTrace_
  )
import State (AppSt (..), AppState)
