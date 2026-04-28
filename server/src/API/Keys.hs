{- HLINT ignore "Use newtype instead of data" -}
module API.Keys where

import Codec.Archive.Zip qualified as ZIP
import Config (S3Config (..))
import Control.Monad (void, replicateM)
import Crypto.Gpgme
import Crypto.Gpgme.Key.Gen qualified as G
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.ByteString.UTF8 qualified as BSU
import Data.Default (def)
import Data.String (fromString)
import Data.Text qualified as T
import Data.UUID qualified as UUID
import Data.UUID.V4 qualified as UUIDV4
import Database.Reports (createReporter)
import Database.Types (Reporter (..))
import Relago.Prelude
import S3
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))
import System.Random

type KeysRoutes :: Type -> Type
newtype KeysRoutes route = MkKeysRoutes
  { exchange :: route :- "exchange" :> MultipartForm Tmp ExchangeKey :> Post '[OctetStream] LBS.ByteString
  }
  deriving stock (Generic)

instance FromMultipart Tmp ExchangeKey where
  fromMultipart multipartData =
    let f = lookupFile "publicKey" multipartData in (MkExchangeKey . fdPayload <$> f) <*> (fdFileName <$> f)

type ExchangeKey :: Type
data ExchangeKey = MkExchangeKey
  { publicKey :: !FilePath
  , fileName :: !Text
  }
  deriving stock (Generic, Show)

deriving anyclass instance ToJSON ExchangeKey
deriving anyclass instance FromJSON ExchangeKey

exchangeKey :: (AppState) => ExchangeKey -> Handler LBS.ByteString
exchangeKey k = do
  uuid <- liftIO UUIDV4.nextRandom

  let c = ?st.config
      keyDir = c.dataDir </> "keys"
      bindedKeyDir = c.dataDir </> "userKey" </> UUID.toString uuid
      pubKey = "public.asc"
      secKey = "secret.asc"
      uKeyN = "userkey.asc"
      s3Con = ?st.s3Con
      pbKeyPath = UUID.toString uuid </> pubKey
      secKeyPath = UUID.toString uuid </> secKey
      userKeyPath = UUID.toString uuid </> uKeyN
      pbKey = UploadObject (bindedKeyDir </> pubKey) (T.pack pbKeyPath)
      scKey = UploadObject (bindedKeyDir </> secKey) (T.pack secKeyPath)
      uKey = UploadObject k.publicKey (T.pack userKeyPath)
      keyPass = "42" -- FIXME: Generate random symbols as password
      reporter = Reporter pbKeyPath secKeyPath userKeyPath $ T.pack keyPass

  liftIO $ createDirectoryIfMissing True keyDir
  liftIO $ createDirectoryIfMissing True bindedKeyDir
  liftIO $ createReporter uuid reporter

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
                \Passphrase: "
                  <> BSU.fromString keyPass
                  <> "\n"
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
                let passphraseCallback _hint _info _prevBad = return (Just keyPass)
                setPassphraseCallback ctx (Just passphraseCallback)

                setArmor True ctx
                -- Export public key using h-gpgme
                pKey <- exportKey ctx fpr
                -- Export secret key using h-gpgme
                sKey <- exportSecretKey ctx fpr
                case (pKey, sKey) of
                  (Right pubKey, Right secKey) -> do
                    -- Save to bindedKeyDir
                    BS.writeFile pbKey.path pubKey
                    BS.writeFile scKey.path secKey
                    void $ liftIO $ uploadObjects s3Con c.s3.s3MainBucket [pbKey, scKey, uKey]

                    let archivePath = bindedKeyDir </> "res.zip"
                        uuidBytes = BSU.fromString $ UUID.toString uuid
                    pubKeyEntry <- ZIP.mkEntrySelector "public.asc"
                    idFileEntry <- ZIP.mkEntrySelector "idfile"
                    ZIP.createArchive archivePath $ do
                      ZIP.addEntry ZIP.Store pubKey pubKeyEntry
                      ZIP.addEntry ZIP.Store uuidBytes idFileEntry

                    pure $ Right archivePath
                  (Left err, _) -> pure $ Left ("Failed to export public key: " <> show err)
                  (_, Left err) -> pure $ Left ("Failed to export secret key: " <> show err)
              [] -> pure $ Left "No encryption subkey found"

  case ret of
    Left err -> throwError $ err500{errBody = "Key generation failed: " <> fromString err}
    Right archivePath -> liftIO $ LBS.readFile archivePath

keysHandlers :: (AppState) => KeysRoutes AsServer
keysHandlers =
  MkKeysRoutes
    { exchange = exchangeKey
    }

randomSymbols :: IO String
randomSymbols = replicateM 10 (randomRIO ('!', '~'))
