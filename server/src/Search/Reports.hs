module Search.Reports where

import Config
import Control.Applicative ((<|>))
import Control.Monad (forM, unless)
import Data.Aeson
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString.Lazy qualified as LBS
import Data.Either (lefts, rights)
import Data.Functor (void)
import Data.Text qualified as T
import Data.Vector qualified as V
import Database.Bloodhound
import Relago.Prelude
import Search (withOpenSearch)

chunksOf :: Int -> V.Vector a -> [V.Vector a]
chunksOf n v
  | V.null v = []
  | otherwise = let (h, t) = V.splitAt n v in h : chunksOf n t

batchSize :: Int
batchSize = 5000

type JournalEntry :: Type
data JournalEntry = JournalEntry
  { jeMessage :: Text
  , jePriority :: Maybe Text
  , jeSyslogFacility :: Maybe Text
  , jeSyslogIdentifier :: Maybe Text
  , jeBootId :: Maybe Text
  , jeHostname :: Maybe Text
  , jeMachineId :: Maybe Text
  , jeTransport :: Maybe Text
  , jeUnit :: Maybe Text
  , jePid :: Maybe Text
  , jeUid :: Maybe Text
  , jeGid :: Maybe Text
  , jeComm :: Maybe Text
  , jeExe :: Maybe Text
  , jeCmdline :: Maybe Text
  , jeSourceMonotonicTimestamp :: Maybe Text
  , jeSourceBoottimeTimestamp :: Maybe Text
  , jeExtra :: Value
  -- ^ Any additional fields
  }
  deriving stock (Eq, Generic, Show)

instance FromJSON JournalEntry where
  parseJSON = withObject "JournalEntry" $ \o -> do
    jeMessage <- o .: "MESSAGE" <|> pure ""
    jePriority <- o .:? "PRIORITY"
    jeSyslogFacility <- o .:? "SYSLOG_FACILITY"
    jeSyslogIdentifier <- o .:? "SYSLOG_IDENTIFIER"
    jeBootId <- o .:? "_BOOT_ID"
    jeHostname <- o .:? "_HOSTNAME"
    jeMachineId <- o .:? "_MACHINE_ID"
    jeTransport <- o .:? "_TRANSPORT"
    jeUnit <- o .:? "_SYSTEMD_UNIT"
    jePid <- o .:? "_PID"
    jeUid <- o .:? "_UID"
    jeGid <- o .:? "_GID"
    jeComm <- o .:? "_COMM"
    jeExe <- o .:? "_EXE"
    jeCmdline <- o .:? "_CMDLINE"
    -- Store all extra fields
    let knownKeys =
          [ "MESSAGE"
          , "PRIORITY"
          , "SYSLOG_FACILITY"
          , "SYSLOG_IDENTIFIER"
          , "_BOOT_ID"
          , "_HOSTNAME"
          , "_MACHINE_ID"
          , "_TRANSPORT"
          , "_SYSTEMD_UNIT"
          , "_PID"
          , "_UID"
          , "_GID"
          , "_COMM"
          , "_EXE"
          , "_CMDLINE"
          ]
        extraFields = KM.filterWithKey (\k _ -> k `notElem` knownKeys) o
    pure JournalEntry{jeExtra = Object extraFields, ..}

instance ToJSON JournalEntry where
  toJSON JournalEntry{..} =
    object
      $ filter
        ((/= Null) . snd)
        [ "message" .= jeMessage
        , "priority" .= jePriority
        , "syslog_facility" .= jeSyslogFacility
        , "syslog_identifier" .= jeSyslogIdentifier
        , "boot_id" .= jeBootId
        , "hostname" .= jeHostname
        , "machine_id" .= jeMachineId
        , "transport" .= jeTransport
        , "unit" .= jeUnit
        , "pid" .= jePid
        , "uid" .= jeUid
        , "gid" .= jeGid
        , "comm" .= jeComm
        , "exe" .= jeExe
        , "cmdline" .= jeCmdline
        , "extra" .= jeExtra
        ]

type JournalMapping :: Type
data JournalMapping = JournalMapping deriving stock (Eq, Show)

instance ToJSON JournalMapping where
  toJSON JournalMapping =
    object
      [ "properties"
          .= object
            [ "message" .= object ["type" .= ("text" :: Text)]
            , "priority" .= object ["type" .= ("keyword" :: Text)]
            , "syslog_facility" .= object ["type" .= ("keyword" :: Text)]
            , "syslog_identifier" .= object ["type" .= ("keyword" :: Text)]
            , "boot_id" .= object ["type" .= ("keyword" :: Text)]
            , "hostname" .= object ["type" .= ("keyword" :: Text)]
            , "machine_id" .= object ["type" .= ("keyword" :: Text)]
            , "transport" .= object ["type" .= ("keyword" :: Text)]
            , "unit" .= object ["type" .= ("keyword" :: Text)]
            , "pid" .= object ["type" .= ("keyword" :: Text)]
            , "uid" .= object ["type" .= ("keyword" :: Text)]
            , "gid" .= object ["type" .= ("keyword" :: Text)]
            , "comm" .= object ["type" .= ("keyword" :: Text)]
            , "exe" .= object ["type" .= ("keyword" :: Text)]
            , "cmdline" .= object ["type" .= ("text" :: Text)]
            ]
      ]

loadJournalLogs :: FilePath -> IO (Either String [JournalEntry]) -- FIXME: Must move another module
loadJournalLogs path = do
  contents <- LBS.readFile path
  pure $ eitherDecode contents

indexJournalLogs :: OpenSearchConfig -> Text -> [JournalEntry] -> IO (Either String Int)
indexJournalLogs cfg idxName entries = do
  case mkIndexName idxName of
    Left err -> pure $ Left $ T.unpack err
    Right index -> do
      let indexSettings = IndexSettings (ShardCount 1) (ReplicaCount 1) defaultIndexMappingsLimits

      -- create if exists
      indx <- withOpenSearch cfg $ do
        exists <- indexExists index
        liftIO $ print $ "Index exists: " <> show exists
        unless exists $ do
          createReply <- createIndex indexSettings index
          liftIO $ print $ "Create index response: " <> show createReply
          mappingReply <- putMapping @Value index JournalMapping
          liftIO $ print $ "Put mapping response: " <> show mappingReply

      case indx of
        Left err -> pure $ Left $ "Failed to create index: " <> show err
        Right _ -> do
          -- Index in batches using Vector
          let entriesVec = V.fromList $ zip [1 ..] entries
              batches = chunksOf batchSize entriesVec
              totalBatches = length batches
          print $ "Indexing " <> show (length entries) <> " entries in " <> show totalBatches <> " batches"

          rs <- forM (zip [1 ..] batches) $ \(bCnt, batch) -> do
            print
              $ "Processing batch " <> show bCnt <> "/" <> show totalBatches <> " (" <> show (V.length batch) <> " entries)"
            result <- withOpenSearch cfg $ do
              let ops = V.map mkBulkOp batch
                  mkBulkOp (i, entry) = BulkIndex index (DocId $ T.pack $ show i) (toJSON entry)
              void $ bulk ops
              liftIO $ putStrLn $ "Batch " <> show bCnt <> " done"
              pure $ V.length batch
            case result of
              Left err -> do
                putStrLn $ "Batch " <> show bCnt <> " failed: " <> show err
                pure $ Left $ show err
              Right n -> pure $ Right n

          case (lefts rs, rights rs) of
            ([], r) -> pure $ Right $ sum r
            (l, []) -> pure $ Left $ "Failed batches : " <> show l
            (_, _) -> pure $ Left "Empty case"

-- | Load and index journal logs from file
indexJournalLogsFromFile :: OpenSearchConfig -> Text -> FilePath -> IO ()
indexJournalLogsFromFile cfg idxName path = do
  result <- loadJournalLogs path
  case result of
    Left err -> print $ "Failed parse: " <> err
    Right entries -> do
      print $ "Journal entries size: " <> show (length entries)
      print idxName
      indexResult <- indexJournalLogs cfg idxName entries
      case indexResult of
        Left err -> print $ "Index create error: " <> err
        Right c -> print $ "Successfully indexed: " <> show c
