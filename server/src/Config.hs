{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingVia #-}

module Config where

import Data.ByteString qualified as BS
import Data.Kind (Constraint, Type)
import Data.Text.Encoding (decodeUtf8)
import GHC.Generics (Generic)
import Toml qualified
import Toml.Schema (FromValue, ToTable, ToValue)
import Toml.Schema.Generic (GenericTomlTable (..))
import Toml.Schema.Matcher (Result (..))

type Config :: Type
data Config = Config
  { dataDir :: !FilePath
  , port :: !Int
  }
  deriving (Eq, Generic, Show)
  deriving (FromValue, ToTable, ToValue) via GenericTomlTable Config

type AppConfig :: Constraint
type AppConfig = (?config :: Config)

loadConfig :: FilePath -> IO (Result Toml.DecodeError Config)
loadConfig filepath = Toml.decode' . decodeUtf8 <$> BS.readFile filepath
