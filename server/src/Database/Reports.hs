module Database.Reports
  ( createReport
  , setReportIndexed
  , createReporter
  ) where

import Data.UUID (UUID)
import Database (withPool)
import Database.Esqueleto (runMigration)
import Database.Persist (insert, insertKey, update, (=.))
import Database.Types (EntityField (Indexed), Key (..), Report (..), ReportId, Reporter (..), ReporterId, migrateAll)
import Relago.Prelude

createReport :: (AppState, MonadIO m) => Text -> Text -> m ReportId
createReport n fp = withPool $ insert $ Report n fp False

setReportIndexed :: (AppState, MonadIO m) => ReportId -> m ()
setReportIndexed reportId = withPool $ update reportId [Indexed =. True]

createReporter :: (AppState, MonadIO m) => UUID -> Reporter -> m ()
createReporter uuid r = withPool $ insertKey (ReporterKey uuid) r
