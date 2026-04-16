module Database.Reports
  ( createReport
  , setReportIndexed
  ) where

import Database (withPool)
import Database.Esqueleto (runMigration)
import Database.Persist (insert, update, (=.))
import Database.Types (EntityField (Indexed), Report (..), ReportId, migrateAll)
import Relago.Prelude

createReport :: (AppState, MonadIO m) => Text -> Text -> m ReportId
createReport n fp = withPool $ insert $ Report n fp False

setReportIndexed :: (AppState, MonadIO m) => ReportId -> m ()
setReportIndexed reportId = withPool $ update reportId [Indexed =. True]
