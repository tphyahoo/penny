-- | The Penny Postings report
--
-- The Postings report displays postings in a tabular format designed
-- to be read by humans. Some terminology used in the Postings report:
--
-- [@row@] The smallest unit that spans from left to right. A row,
-- however, might consist of more than one screen line. For example,
-- the running balance is shown on the far right side of the Postings
-- report. The running balance might consist of more than one
-- commodity. Each commodity is displayed on its own screen
-- line. However, all these lines put together are displayed in a
-- single row.
--
-- [@column@] The smallest unit that spans from top to bottom.
--
-- [@tranche@] Each posting is displayed in several rows. The group of
-- rows that is displayed for a single posting is called a tranche.
--
-- [@tranche row@] Each tranche has a particular number of rows
-- (currently four); each of these rows is known as a tranche row.
--
-- [@field@] Corresponds to a particular element of the posting, such
-- as whether it is a debit or credit or its payee. The user can
-- select which fields to see.
--
-- [@allocation@] The width of the Payee and Account fields is
-- variable. Generally their width will adjust to fill the entire
-- width of the screen. The allocations of the Payee and Account
-- fields determine how much of the remaining space each field will
-- receive.
--
-- The Postings report is easily customized from the command line to
-- show various fields. However, the order of the fields is not
-- configurable without editing the source code (sorry).

module Penny.Cabin.Postings (report) where

import qualified Control.Monad.Exception.Synchronous as Ex
import qualified Data.Text as X
import Text.Matchers.Text (CaseSensitive)
import System.Console.MultiArg.Prim (ParserE)

import Penny.Cabin.Postings.Claimer (claimer)
import Penny.Cabin.Postings.Grower (grower)
import Penny.Cabin.Postings.Allocator (allocator)
import Penny.Cabin.Postings.Finalizer (finalizer)
import Penny.Cabin.Postings.Help (help)

import qualified Penny.Cabin.Colors as C
import qualified Penny.Cabin.Postings.Fields as F
import qualified Penny.Cabin.Postings.Grid as G
import qualified Penny.Cabin.Postings.Options as O
import qualified Penny.Cabin.Postings.Parser as P
import qualified Penny.Cabin.Interface as I

import Penny.Liberty.Operators (getPredicate)
import Penny.Liberty.Error (Error)
import qualified Penny.Liberty.Types as LT

import qualified Penny.Shield as S

printReport ::
  F.Fields Bool
  -> O.Options
  -> (LT.PostingInfo -> Bool)
  -> [LT.PostingInfo]
  -> Maybe C.Chunk
printReport flds o =
  G.report (f claimer) (f grower) (f allocator) (f finalizer) where
    f fn = fn flds o

makeReportFunc ::
  F.Fields Bool
  -> O.Options
  -> P.State
  -> [LT.PostingInfo]
  -> a
  -> Ex.Exceptional X.Text C.Chunk
makeReportFunc f o s ps _ = case getPredicate (P.tokens s) of
  Nothing -> Ex.Exception (X.pack "postings: bad expression")
  Just p -> Ex.Success $ case printReport f o p ps of
    Nothing -> C.emptyChunk
    Just c -> c

makeReportParser ::
  (S.Runtime -> (F.Fields Bool, O.Options))
  -> S.Runtime
  -> CaseSensitive
  -> (X.Text -> Ex.Exceptional X.Text (X.Text -> Bool))
  -> ParserE Error (I.ReportFunc, C.ColorPref)
makeReportParser rf rt c fact = do
  let (flds, opts) = rf rt
  s <- P.parseCommand (S.currentTime rt) opts c fact
  let colorPref = P.colors s
      reportFunc = makeReportFunc flds opts s
  return (reportFunc, colorPref)

-- | Creates a Postings report. Apply this function to your
-- customizations.
report ::
  (S.Runtime -> (F.Fields Bool, O.Options))
  -- ^ Function that, when applied to a a data type that holds various
  -- values that can only be known at runtime (such as the width of
  -- the screen, the TERM environment variable, and whether standard
  -- output is a terminal) returns which fields to show and the
  -- default report options. This way you can configure your options
  -- depending upon the runtime environment. (You can always ignore
  -- the runtime variable if you don't care about that stuff when
  -- configuring your options.) The fields and options returned by
  -- this function can be overridden on the command line.

  -> I.Report
report rf = I.Report help rpt where
  rpt = makeReportParser rf
