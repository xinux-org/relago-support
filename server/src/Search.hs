module Search
  ( OpenSearchConfig (..)
  , withOpenSearch
  ) where

import Config
import Data.Default (def)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Database.Bloodhound
import Network.Connection (TLSSettings (..))
import Network.HTTP.Client
import Network.HTTP.Client.TLS (mkManagerSettings, newTlsManagerWith)

-- | TLS settings that skip certificate verification
insecureTlsSettings :: TLSSettings
insecureTlsSettings =
  TLSSettingsSimple
    { settingDisableCertificateValidation = True
    , settingDisableSession = False
    , settingUseServerName = False
    , settingClientSupported = def
    }

-- | Add basic auth to requests
addBasicAuth :: OpenSearchConfig -> Request -> Request
addBasicAuth cfg = applyBasicAuth u p
 where
  u = encodeUtf8 cfg.osUser
  p = encodeUtf8 cfg.osPassword

-- | Run OpenSearch query with auth
withOpenSearch :: OpenSearchConfig -> BH IO a -> IO (Either EsError a)
withOpenSearch cfg action = do
  let serverUrl = "https://" <> T.unpack cfg.osHost <> ":" <> show cfg.osPort
      server = Server $ T.pack serverUrl
      mSt = mkManagerSettings insecureTlsSettings Nothing -- FIXME: Support secure TLS
  manager <- newTlsManagerWith mSt
  let env = mkBHEnv server manager
      envWithAuth = env{bhRequestHook = pure . addBasicAuth cfg}
  runBH envWithAuth action
