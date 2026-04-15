module Database where

import Database.Esqueleto (runMigration)
import Database.Persist.Sql (SqlPersistT, runSqlPool)
import Database.Types (migrateAll)
import Relago.Prelude

withPool :: (AppState, MonadIO m) => SqlPersistT IO a -> m a
withPool q = liftIO $ runSqlPool q ?st.db

migrate' :: (AppState) => IO ()
migrate' = withPool $ runMigration migrateAll
