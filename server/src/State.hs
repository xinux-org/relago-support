module State where

import Config
import Database.Types
import Data.Kind (Constraint)

data AppSt = MkAppSt
  { config :: Config
  , db :: PoolSql
  }

type AppState :: Constraint
type AppState = (?st :: AppSt)
