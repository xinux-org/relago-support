{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Database.Types where

import Data.Aeson (FromJSON, ToJSON)
import Data.Kind (Type)
import Data.Pool (Pool)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)
import Data.UUID (UUID)
import Data.UUID qualified as UUID
import Database.Esqueleto.Experimental
import Database.Persist.TH
import GHC.Generics (Generic)
import Web.PathPieces (PathPiece (..))

instance PersistField UUID where
  toPersistValue = PersistText . UUID.toText
  fromPersistValue = \case
    PersistText t -> parseUUID t
    PersistLiteral_ _ bs -> parseUUID $ decodeUtf8 bs
    PersistByteString bs -> parseUUID $ decodeUtf8 bs
    _ -> Left "Expected PersistText or PersistLiteral for UUID"
    where
      parseUUID = maybe (Left "Invalid UUID") Right . UUID.fromText

instance PersistFieldSql UUID where
  sqlType _ = SqlOther "UUID"

instance PathPiece UUID where
  fromPathPiece = UUID.fromText
  toPathPiece = UUID.toText

type PoolSql = Pool SqlBackend

share
  [mkPersist sqlSettings{mpsPrefixFields = False}, mkMigrate "migrateAll"]
  [persistLowerCase|
  Report sql=reports
    name Text
    filePath Text
    indexed Bool
    deriving Eq
  Reporter sql=reporters
    Id UUID default=gen_random_uuid()
    privateKey FilePath
    secretKey FilePath
    userKey FilePath
    keyPass Text
    deriving Eq
|]

type Report :: Type
type ReportId :: Type

deriving stock instance Generic Report
deriving stock instance Show Report
deriving anyclass instance FromJSON Report

type Reporter :: Type
type ReporterId :: Type

deriving stock instance Generic Reporter
deriving stock instance Show Reporter
deriving anyclass instance FromJSON Reporter
deriving anyclass instance ToJSON Reporter
