{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module API.Upload where

import Relago.Prelude

import Codec.Archive.Zip qualified as ZIP
import Codec.Compression.Zlib qualified as Zlib
import Control.Monad (void)
import Data.ByteString.Lazy qualified as LBS
import Data.List (find)
import Data.Map qualified as M
import Data.Time.Clock.POSIX (getPOSIXTime)
import Servant hiding (Param)
import Servant.Multipart
import Servant.Server.Generic (AsServer)
import System.Directory (renameFile)
import System.FilePath (addExtension, dropExtension, isExtensionOf, (</>))

type UploadRoutes :: Type -> Type
newtype UploadRoutes route = MkUploadRoutes
  { _log :: route :- "report" :> MultipartForm Tmp Report :> Post '[JSON] Integer
  }
  deriving stock (Generic)

type Report :: Type
data Report = MkReport {report :: !FilePath, fileName :: !Text} deriving stock (Show)
instance FromMultipart Tmp Report where
  fromMultipart multipartData =
    let f = lookupFile "report" multipartData in (MkReport . fdPayload <$> f) <*> (fdFileName <$> f)

upload :: (AppState) => Report -> Handler Integer
upload r = do
  let c = ?st.config
  liftIO $ do
    tm <- getPOSIXTime -- FIXME: Use something unique identificator generator for rename archive file
    let dataPath = c.dataDir
        archiveFileName = show tm
        archiveFile = addExtension archiveFileName "zip"
        filePath = dataPath </> archiveFile
        unzipFolder = dataPath </> archiveFileName

    renameFile r.report filePath
    void $ ZIP.withArchive filePath (ZIP.unpackInto unzipFolder) -- Unpack zip archive
    entries <- ZIP.withArchive filePath (M.keys <$> ZIP.getEntries)

    let jr = find (isExtensionOf "zlib") $ ZIP.unEntrySelector <$> entries
    case jr of -- FIXME: simlify code
      Just j -> do
        let fname = dropExtension j
        cmp <- LBS.readFile $ unzipFolder </> j
        LBS.writeFile (unzipFolder </> fname) $ Zlib.decompress cmp
      Nothing -> print "Journal not found" -- FIXME: Handle error
    print r
  return 0

uploadHandlers :: (AppState) => UploadRoutes AsServer
uploadHandlers =
  MkUploadRoutes
    { _log = upload
    }
