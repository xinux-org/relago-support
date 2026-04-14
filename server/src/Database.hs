module Database where

import Relago.Prelude

import Database.Persist.Sql (SqlPersistT, runSqlPool)

withPool :: (AppState, MonadIO m) => SqlPersistT IO a -> m a
withPool q = liftIO $ runSqlPool q ?st.db

