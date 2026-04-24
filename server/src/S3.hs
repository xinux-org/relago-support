module S3 where

import Config (S3Config (..))
import Control.Monad (forM)
import Data.Either (lefts, rights)
import Data.Function ((&))
import Data.String (fromString)
import Data.Text (Text)
import Network.Minio

s3Conn :: S3Config -> ConnectInfo
s3Conn S3Config{..} =
  fromString s3Url
    & setRegion s3Region
    & setCreds creds
 where
  creds = CredentialValue (AccessKey s3KeyId) (fromString s3SecretKey) Nothing

data UploadObject = UploadObject
  { path :: FilePath
  , objectName :: Text
  }
  deriving stock (Show)

uploadObjects :: ConnectInfo -> Text -> [UploadObject] -> IO ()
uploadObjects c bucket contents = do
  let upl = fPutObject bucket
  rs <- forM contents $ \cnt -> do
    runMinio c $ upl cnt.objectName cnt.path defaultPutObjectOptions
  case (lefts rs, rights rs) of -- FIXME: Refactor handling results
    ([], r) -> print $ "Success"
    (l, []) -> print $ "Failed uploades : " <> show l
    (_, _) -> print "Empty case"

  print "uploaded"
