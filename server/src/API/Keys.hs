{-# LANGUAGE OverloadedStrings #-}

{- HLINT ignore "Use newtype instead of data" -}
module API.Keys where

import Config (AppConfig, Config (..))
import Control.Monad.IO.Class (MonadIO (liftIO))
import Crypto.Gpgme
import Crypto.Gpgme.Key.Gen qualified as G
import Data.Aeson (FromJSON, ToJSON)
import Data.Default
import Data.Kind (Type)
import Data.String (fromString)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)
import GHC.Generics (Generic)
import Servant hiding (Param)
import Servant.Server.Generic (AsServer)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

type KeysRoutes :: Type -> Type
newtype KeysRoutes route = MkKeysRoutes
  { exchange :: route :- "exchange" :> ReqBody '[JSON] ExchangeKey :> Post '[JSON] ExchangeKey
  }
  deriving stock (Generic)

type ExchangeKey :: Type
data ExchangeKey = MkExchangeKey
  { publicKey :: !Text
  }
  deriving stock (Generic, Show)

deriving anyclass instance ToJSON ExchangeKey
deriving anyclass instance FromJSON ExchangeKey

exchangeKey :: (?config :: Config) => ExchangeKey -> Handler ExchangeKey
exchangeKey _k = do
  let c = ?config
      keyDir = c.dataDir </> "keys"

  liftIO $ createDirectoryIfMissing True keyDir

  ret <- liftIO $ withCtx keyDir "C" OpenPGP $ \ctx -> do
    -- FIXME: Remove raw params, use 256-bit fixed key length
    let params =
          (def :: G.GenKeyParams)
            { G.keyType = Nothing
            , G.keyLength = Nothing
            , G.rawParams =
                "Key-Type: EDDSA\n\
                \Key-Curve: ed25519\n\
                \Subkey-Type: ECDH\n\
                \Subkey-Curve: cv25519\n\
                \Name-Real: Toshmat\n\
                \Name-Comment: (pp=42)\n\
                \Name-Email: toshmat@xinux.uz\n\
                \Expire-Date: 0\n\
                \Passphrase: 42\n"
            }
    genResult <- G.genKey ctx params
    case genResult of
      Left err -> pure $ Left (show err)
      Right fpr -> do
        maybeKey <- getKey ctx fpr WithSecret
        case maybeKey of
          Nothing -> pure $ Left "Failed to retrieve generated key"
          Just key -> do
            let subkeys = keySubKeys key
            case drop 1 subkeys of
              (encryptionKey : _) -> pure $ Right (decodeUtf8 (subkeyFpr encryptionKey))
              [] -> pure $ Left "No encryption subkey found"

  case ret of
    Left err -> throwError $ err500{errBody = "Key generation failed: " <> fromString err}
    Right encryptionKeyFpr -> do
      return
        $ MkExchangeKey
          { publicKey = encryptionKeyFpr
          }

keysHandlers :: (AppConfig) => KeysRoutes AsServer
keysHandlers =
  MkKeysRoutes
    { exchange = exchangeKey
    }
