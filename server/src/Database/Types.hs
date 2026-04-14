module Database.Types where

import Data.Pool (Pool)
import Database.Persist.SqlBackend (SqlBackend)

type PoolSql = Pool SqlBackend
