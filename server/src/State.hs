module State where

import Config
import Data.Kind (Constraint)
import Database.Types
import Log (Logger)
import Network.Minio (ConnectInfo)

data AppSt = MkAppSt
  { config :: Config
  , db :: PoolSql
  , s3Con :: ConnectInfo
  , logger :: Logger
  }

type AppState :: Constraint
type AppState = (?st :: AppSt)
