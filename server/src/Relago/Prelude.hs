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
  ) where

import Config (Config (..))
import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Kind (Constraint, Type)
import Data.Text (Text)
import GHC.Generics (Generic)
import State (AppSt (..), AppState)
