{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Database.Types where

import Data.Aeson (FromJSON)
import Data.Kind (Type)
import Data.Pool (Pool)
import Data.Text (Text)
import Database.Esqueleto.Experimental
import Database.Persist.SqlBackend (SqlBackend)
import Database.Persist.TH
import GHC.Generics (Generic)
import GHC.Records (HasField (..))

type PoolSql = Pool SqlBackend

share
  [mkPersist sqlSettings{mpsPrefixFields = False}, mkMigrate "migrateAll"]
  [persistLowerCase|
  Report sql=reports
    name Text
    filePath Text
    indexed Bool
    deriving Eq
|]

type Report :: Type
type ReportId :: Type

deriving stock instance Generic Report
deriving stock instance Show Report
deriving anyclass instance FromJSON Report
