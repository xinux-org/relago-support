module Database.Reports
  ( createReport
  , setReportIndexed
  , notIndexedReports
  , createReporter
  , getReporterById
  ) where

import Data.UUID (UUID)
import Database (withPool)
import Database.Esqueleto.Experimental (Entity (..), from, select, table, val, where_, (==.))
import Database.Persist (get, insert, insertKey, update, (=.))
import Database.Types (EntityField (Indexed), Key (..), Report (..), ReportId, Reporter (..))
import Relago.Prelude

createReport :: (AppState, MonadIO m) => Text -> Text -> m ReportId
createReport n fp = withPool $ insert $ Report n fp False

setReportIndexed :: (AppState, MonadIO m) => ReportId -> m ()
setReportIndexed reportId = withPool $ update reportId [Indexed =. True]

notIndexedReports :: (AppState, MonadIO m) => m [(ReportId, Report)]
notIndexedReports = withPool $ do
  results <- select $ do
    report <- from $ table @Report
    where_ (report.indexed ==. val False)
    pure report
  pure $ (\(Entity k v) -> (k, v)) <$> results

createReporter :: (AppState, MonadIO m) => UUID -> Reporter -> m ()
createReporter uuid r = withPool $ insertKey (ReporterKey uuid) r

getReporterById :: (AppState, MonadIO m) => UUID -> m (Maybe Reporter)
getReporterById uuid = withPool $ get (ReporterKey uuid)
