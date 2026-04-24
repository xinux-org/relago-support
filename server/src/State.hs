module State where

import Config
import Data.Kind (Constraint)
import Database.Types
import Network.Minio (ConnectInfo)

data AppSt = MkAppSt
  { config :: Config
  , db :: PoolSql
  , s3Con :: ConnectInfo
  }

type AppState :: Constraint
type AppState = (?st :: AppSt)
