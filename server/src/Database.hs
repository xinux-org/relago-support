module Database where

import Database.Persist.Sql (SqlPersistT, runSqlPool)
import Relago.Prelude

withPool :: (AppState, MonadIO m) => SqlPersistT IO a -> m a
withPool q = liftIO $ runSqlPool q ?st.db
