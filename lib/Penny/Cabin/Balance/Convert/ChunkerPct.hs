{-# LANGUAGE OverloadedStrings #-}
module Penny.Cabin.Balance.Convert.ChunkerPct
  ( MainRow(..)
  , OneColRow(..)
  , Row(..)
  , Percent(..)
  , rowsToChunks
  ) where


import Control.Applicative
  (Applicative (pure), (<$>), (<*>))
import Data.Monoid (mempty)
import qualified Penny.Cabin.Scheme as E
import qualified Penny.Cabin.Meta as Meta
import qualified Penny.Cabin.Row as R
import qualified Penny.Lincoln as L
import qualified Data.Foldable as Fdbl
import qualified Data.Text as X
import qualified System.Console.Rainbow as Rb
import Penny.Cabin.Balance.Convert.Parser (RoundTo, unRoundTo)
import Text.Printf (printf)

type IsEven = Bool

data Columns a = Columns {
  acct :: a
  , drCr :: a
  , quantity :: a
  } deriving Show

instance Functor Columns where
  fmap f c = Columns {
    acct = f (acct c)
    , drCr = f (drCr c)
    , quantity = f (quantity c)
    }

instance Applicative Columns where
  pure a = Columns a a a
  fn <*> fa = Columns {
    acct = (acct fn) (acct fa)
    , drCr = (drCr fn) (drCr fa)
    , quantity = (quantity fn) (quantity fa)
     }

data PreSpec = PreSpec {
  _justification :: R.Justification
  , _padSpec :: (E.Label, E.EvenOdd)
  , bits :: Rb.Chunk }

-- | When given a list of columns, determine the widest row in each
-- column.
maxWidths :: [Columns PreSpec] -> Columns R.Width
maxWidths = Fdbl.foldl' maxWidthPerColumn (pure (R.Width 0))

-- | Applied to a Columns of PreSpec and a Colums of widths, return a
-- Columns that has the wider of the two values.
maxWidthPerColumn ::
  Columns R.Width
  -> Columns PreSpec
  -> Columns R.Width
maxWidthPerColumn w p = f <$> w <*> p where
  f old new = max old (R.Width . X.length . Rb._text . bits $ new)

-- | Changes a single set of Columns to a set of ColumnSpec of the
-- given width.
preSpecToSpec ::
  Columns R.Width
  -> Columns PreSpec
  -> Columns R.ColumnSpec
preSpecToSpec ws p = f <$> ws <*> p where
  f width (PreSpec j ps bs) = R.ColumnSpec j width ps [bs]

resizeColumnsInList :: [Columns PreSpec] -> [Columns R.ColumnSpec]
resizeColumnsInList cs = map (preSpecToSpec w) cs where
  w = maxWidths cs


widthSpacerAcct :: Int
widthSpacerAcct = 4

widthSpacerDrCr :: Int
widthSpacerDrCr = 1

colsToBits
  :: E.Changers
  -> IsEven
  -> Columns R.ColumnSpec
  -> [Rb.Chunk]
colsToBits chgrs isEven (Columns a dc q) = let
  fillSpec = if isEven
             then (E.Other, E.Even)
             else (E.Other, E.Odd)
  spacer w = R.ColumnSpec j (R.Width w) fillSpec []
  j = R.LeftJustify
  cs = a
       : spacer widthSpacerAcct
       : dc
       : spacer widthSpacerDrCr
       : q
       : []
  in R.row chgrs cs

colsListToBits
  :: E.Changers
  -> [Columns R.ColumnSpec]
  -> [[Rb.Chunk]]
colsListToBits chgrs = zipWith f bools where
  f b c = colsToBits chgrs b c
  bools = iterate not True

preSpecsToBits
  :: E.Changers
  -> [Columns PreSpec]
  -> [Rb.Chunk]
preSpecsToBits chgrs =
  concat
  . colsListToBits chgrs
  . resizeColumnsInList

data Row = RMain MainRow | ROneCol OneColRow

-- | Displays a one-column row.
data OneColRow = OneColRow {
  ocIndentation :: Int
  -- ^ Indent the text by this many levels (not by this many
  -- spaces; this number is multiplied by another number in the
  -- Chunker source to arrive at the final indentation amount)

  , ocText :: X.Text
  -- ^ Text for the left column
  }

data Percent = Percent
  { pctDrCr :: L.DrCr
  , pctAmount :: Double
  } deriving (Eq, Show)


-- | Displays a Double, rounded to the specified number of decimal
-- places.
dispRounded :: RoundTo -> Double -> X.Text
dispRounded rnd
  = X.pack
  . printf ("%." ++ show (L.unNonNegative . unRoundTo $ rnd) ++ "f")

-- | Displays a single account in a Balance report. In a
-- single-commodity report, this account will only be one screen line
-- long. In a multi-commodity report, it might be multiple lines long,
-- with one screen line for each commodity.
data MainRow = MainRow {
  mrIndentation :: Int
  -- ^ Indent the account name by this many levels (not by this many
  -- spaces; this number is multiplied by another number in the
  -- Chunker source to arrive at the final indentation amount)

  , mrText :: X.Text
  -- ^ Text for the name of the account

  , mrPercent :: Maybe Percent
  -- ^ If Nothing, display dashes for the percent.
  }


rowsToChunks
  :: E.Changers
  -> RoundTo
  -- ^ Round by this many places
  -> [Row]
  -> [Rb.Chunk]
rowsToChunks chgrs rnd =
  preSpecsToBits chgrs
  . rowsToColumns chgrs rnd

rowsToColumns
  :: E.Changers
  -> RoundTo
  -- ^ Round by this many places

  -> [Row]
  -> [Columns PreSpec]
rowsToColumns chgrs rnd
  = map (mkRow chgrs rnd)
  . L.serialItems (\ser r -> (Meta.VisibleNum ser, r))


mkRow
  :: E.Changers
  -> RoundTo
  -> (Meta.VisibleNum, Row)
  -> Columns PreSpec
mkRow chgrs rnd (vn, r) = case r of
  RMain m -> mkMainRow chgrs rnd (vn, m)
  ROneCol c -> mkOneColRow chgrs (vn, c)

mkOneColRow
  :: E.Changers
  -> (Meta.VisibleNum, OneColRow)
  -> Columns PreSpec
mkOneColRow chgrs (vn, (OneColRow i t)) = Columns ca cd cq
  where
    txt = X.append indents t
    indents = X.replicate (indentAmount * max 0 i)
              (X.singleton ' ')
    eo = E.fromVisibleNum vn
    lbl = E.Other
    ca = PreSpec R.LeftJustify (lbl, eo)
         (E.getEvenOddLabelValue lbl eo chgrs . Rb.Chunk mempty $ txt)
    cd = PreSpec R.LeftJustify (lbl, eo)
         (E.getEvenOddLabelValue lbl eo chgrs mempty)
    cq = cd

mkMainRow
  :: E.Changers
  -> RoundTo
  -> (Meta.VisibleNum, MainRow)
  -> Columns PreSpec
mkMainRow chgrs rnd (vn, (MainRow i acctTxt b)) = Columns ca cd cq
  where
    applyFmt = E.getEvenOddLabelValue lbl eo chgrs
    eo = E.fromVisibleNum vn
    lbl = E.Other
    ca = PreSpec R.LeftJustify (lbl, eo) (applyFmt (Rb.Chunk mempty txt))
      where
        txt = X.append indents acctTxt
        indents = X.replicate (indentAmount * max 0 i)
                  (X.singleton ' ')
    cd = PreSpec R.LeftJustify (lbl, eo) (applyFmt cksDrCr)
    cq = PreSpec R.LeftJustify (lbl, eo) (applyFmt cksQty)
    (cksDrCr, cksQty) = balanceChunks chgrs rnd vn b


balanceChunks
  :: E.Changers
  -> RoundTo
  -> Meta.VisibleNum
  -> Maybe Percent
  -> (Rb.Chunk, Rb.Chunk)
balanceChunks chgrs rnd vn pct = (chkDc, chkQt)
  where
    eo = E.fromVisibleNum vn
    chkDc = E.bottomLineToDrCr (fmap pctDrCr pct) eo chgrs
    qtFmt = E.getEvenOddLabelValue lbl eo chgrs
    chkQt = qtFmt $ Rb.Chunk mempty t
    (lbl, t) = case pct of
      Nothing -> (E.Zero, X.pack "--")
      Just (Percent dc qt) ->
        (E.dcToLbl dc, dispRounded rnd . (* 100) $ qt)


indentAmount :: Int
indentAmount = 2

