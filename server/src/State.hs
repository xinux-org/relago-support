module State where

import Config
import Data.Kind (Constraint)
import Database.Types

data AppSt = MkAppSt
  { config :: Config
  , db :: PoolSql
  }

type AppState :: Constraint
type AppState = (?st :: AppSt)
