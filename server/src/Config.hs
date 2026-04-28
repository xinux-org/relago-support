{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingVia #-}

module Config
  ( Environment (..)
  , envLogLevel
  , Config (..)
  , OpenSearchConfig (..)
  , S3Config (..)
  , loadConfig
  ) where

import Data.ByteString qualified as BS
import Data.Kind (Type)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (decodeUtf8)
import GHC.Generics (Generic)
import Log (LogLevel (..))
import Toml qualified
import Toml.Schema (FromValue (..), ToTable, ToValue (..), parseTableFromValue, reqKey)
import Toml.Schema.Generic (GenericTomlTable (..))
import Toml.Schema.Matcher (Result (..))

data Environment
  = Development
  | Production
  deriving (Bounded, Enum, Eq, Generic, Show)

envLogLevel :: Environment -> LogLevel
envLogLevel = \case
  Development -> LogTrace
  Production -> LogInfo

instance FromValue Environment where
  fromValue = \case
    Toml.Text' _ t -> case T.toLower t of
      "development" -> pure Development
      "dev" -> pure Development
      "production" -> pure Production
      "prod" -> pure Production
      _ -> fail $ "Unknown value: " <> T.unpack t <> ". accepted oneof: [development, dev, production, prod]"
    _ -> fail "Expected string for environment"

instance ToValue Environment where
  toValue Development = Toml.Text "development"
  toValue Production = Toml.Text "production"

data OpenSearchConfig = OpenSearchConfig
  { osHost :: !Text
  , osPort :: !Int
  , osUser :: !Text
  , osPassword :: !Text
  }
  deriving (Eq, Generic, Show)
  deriving (FromValue, ToTable, ToValue) via GenericTomlTable OpenSearchConfig

data S3Config = S3Config
  { s3Url :: !String
  , s3KeyId :: !Text
  , s3SecretKey :: !String
  , s3Region :: !Text
  , s3MainBucket :: !Text
  }
  deriving (Eq, Generic, Show)
  deriving (FromValue, ToTable, ToValue) via GenericTomlTable S3Config

type Config :: Type
data Config = Config
  { environment :: !Environment
  , dataDir :: !FilePath
  , port :: !Int
  , database :: !Text
  , databasePoolSize :: !Int
  , openSearch :: !OpenSearchConfig
  , s3 :: !S3Config
  }
  deriving (Eq, Generic, Show)
  deriving (ToTable, ToValue) via GenericTomlTable Config

instance FromValue Config where
  fromValue = parseTableFromValue do
    environment <- reqKey "environment"
    dataDir <- reqKey "dataDir"
    port <- reqKey "port"
    database <- reqKey "database"
    databasePoolSize <- reqKey "databasePoolSize"
    openSearch <- reqKey "openSearch"
    s3 <- reqKey "s3"
    pure Config{..}

loadConfig :: FilePath -> IO (Result Toml.DecodeError Config)
loadConfig filepath = Toml.decode' . decodeUtf8 <$> BS.readFile filepath
