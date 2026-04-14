module Database where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Database.Persist.Sql (SqlPersistT, runSqlPool)
import State (AppState, AppSt (..))

withPool :: (AppState, MonadIO m) => SqlPersistT IO a -> m a
withPool q = liftIO $ runSqlPool q ?st.db

