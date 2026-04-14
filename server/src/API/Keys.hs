{- HLINT ignore "Use newtype instead of data" -}
module API.Keys where

import Crypto.Gpgme
import Crypto.Gpgme.Key.Gen qualified as G
import Data.ByteString qualified as BS
import Data.Default (def)
import Data.String (fromString)
import Data.Text.Encoding (decodeUtf8)
import Relago.Prelude
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

exchangeKey :: (AppState) => ExchangeKey -> Handler ExchangeKey
exchangeKey _k = do
  let c = ?st.config
      keyDir = c.dataDir </> "keys"
      bindedKeyDir = c.dataDir </> "userKey"

  liftIO $ createDirectoryIfMissing True keyDir
  liftIO $ createDirectoryIfMissing True bindedKeyDir

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
              (encryptionKey : _) -> do
                let passphrase = "42"
                    passphraseCallback _hint _info _prevBad = return (Just passphrase)
                setPassphraseCallback ctx (Just passphraseCallback)
                -- Export public key using h-gpgme
                pKey <- exportKey ctx fpr
                -- Export secret key using h-gpgme
                sKey <- exportSecretKey ctx fpr
                case (pKey, sKey) of
                  (Right pubKey, Right secKey) -> do
                    -- Save to bindedKeyDir
                    BS.writeFile (bindedKeyDir </> "public.asc") pubKey
                    BS.writeFile (bindedKeyDir </> "secret.asc") secKey
                    pure $ Right (decodeUtf8 (subkeyFpr encryptionKey))
                  (Left err, _) -> pure $ Left ("Failed to export public key: " <> show err)
                  (_, Left err) -> pure $ Left ("Failed to export secret key: " <> show err)
              [] -> pure $ Left "No encryption subkey found"

  case ret of
    Left err -> throwError $ err500{errBody = "Key generation failed: " <> fromString err}
    Right encryptionKeyFpr -> do
      return
        $ MkExchangeKey
          { publicKey = encryptionKeyFpr
          }

keysHandlers :: (AppState) => KeysRoutes AsServer
keysHandlers =
  MkKeysRoutes
    { exchange = exchangeKey
    }
