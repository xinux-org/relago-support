{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingVia #-}

module Config where

import Data.ByteString qualified as BS
import Data.Kind (Type)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)
import GHC.Generics (Generic)
import Toml qualified
import Toml.Schema (FromValue, ToTable, ToValue)
import Toml.Schema.Generic (GenericTomlTable (..))
import Toml.Schema.Matcher (Result (..))

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
  { dataDir :: !FilePath
  , port :: !Int
  , database :: !Text
  , databasePoolSize :: !Int
  , openSearch :: !OpenSearchConfig
  , s3 :: !S3Config
  }
  deriving (Eq, Generic, Show)
  deriving (FromValue, ToTable, ToValue) via GenericTomlTable Config

loadConfig :: FilePath -> IO (Result Toml.DecodeError Config)
loadConfig filepath = Toml.decode' . decodeUtf8 <$> BS.readFile filepath
