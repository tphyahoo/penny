-- | Step 7 - Space claim. See the documentation in
-- "Penny.Cabin.Postings.Grid" for details about how this fits in to
-- the process.
module Penny.Cabin.Postings.Claimer where

import Control.Applicative ((<$>), (<*>), pure)
import qualified Data.Array as A
import Data.Map ((!))
import qualified Data.Map as M
import Data.Maybe (isJust)
import qualified Data.Text as X

import qualified Penny.Lincoln.Balance as Bal
import qualified Penny.Lincoln.Meta as Me
import qualified Penny.Lincoln.Queries as Q
import Penny.Lincoln.HasText (text)
import qualified Penny.Lincoln.HasText as HT

import Penny.Cabin.Postings.Address (Col, Row)
import qualified Penny.Cabin.Postings.Address as Adr
import qualified Penny.Cabin.Postings.Types as T
import qualified Penny.Cabin.Postings.Fields as F
import qualified Penny.Cabin.Postings.Options as O

ifShown ::
  (F.Fields Bool -> Bool)
  -> O.Options a
  -> Maybe T.ClaimedWidth
  -> Maybe T.ClaimedWidth
ifShown fn opts mt =
  if fn (O.fields opts)
  then mt
  else Nothing
 
type Claimer a = 
  O.Options a
  -> A.Array (Col, (T.VisibleNum, Row)) T.PostingInfo
  -> (Col, (T.VisibleNum, Row))
  -> T.PostingInfo
  -> Maybe T.ClaimedWidth

claimer :: Claimer a
claimer opts a (col, (vn, r)) p = let
  f = claimLookup ! (col, r) in
  f opts a (col, (vn, r)) p

claimLookup :: M.Map (Col, Row) (Claimer a)
claimLookup = foldl (flip . uncurry $ M.insert) noClaims ls where
  noClaims = M.fromList
    $ (,)
    <$> A.range ((minBound, minBound), (maxBound, maxBound))
    <*> pure noClaim
  ls = [lineNum, sLineNum, date, sDate,
        flag, sFlag, number, sNumber,
        payee, sPayee, account, sAccount,
        postingDrCr, sPostingDrCr, postingCmdty, sPostingCmdty,
        postingQty, sPostingQty, totalDrCr, sTotalDrCr,
        totalCmdty, sTotalCmdty, totalQty]

noClaim :: Claimer a
noClaim _ _ _ _ = Nothing

claimOne :: Maybe T.ClaimedWidth
claimOne = Just $ T.ClaimedWidth 1

claimOneIf :: Bool -> Maybe T.ClaimedWidth
claimOneIf b =
  if b
  then claimOne
  else Nothing

lineNum :: ((Col, Row), Claimer a)
lineNum = ((Adr.LineNum, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.lineNum opts $
    case Q.postingLine . T.postingBox $ p of
      Nothing -> Nothing
      (Just n) ->
        Just
        . T.ClaimedWidth
        . length
        . show
        . Me.unLine
        . Me.unPostingLine
        $ n

sLineNum :: ((Col, Row), Claimer a)
sLineNum = ((Adr.SLineNum, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.lineNum opts
    . claimOneIf
    . isJust
    . Q.postingLine
    . T.postingBox
    $ p

date :: ((Col, Row), Claimer a)
date = ((Adr.Date, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.date opts $
    Just
    . T.ClaimedWidth
    . X.length
    . O.dateFormat opts
    $ p

sDate :: ((Col, Row), Claimer a)
sDate = ((Adr.SDate, Adr.Top), f) where
  f opts _ _ _ = ifShown F.date opts claimOne


flag :: ((Col, Row), Claimer a)
flag = ((Adr.Multi, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.flag opts $
    case Q.flag . T.postingBox $ p of
      Nothing -> Nothing
      (Just fl) ->
        Just
        . T.ClaimedWidth
        . (+ 2)
        . X.length
        . text
        $ fl

sFlag :: ((Col, Row), Claimer a)
sFlag = ((Adr.SMulti, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.flag opts
    . claimOneIf
    . isJust
    . Q.flag
    . T.postingBox
    $ p

number :: ((Col, Row), Claimer a)
number = ((Adr.Num, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.number opts $
    case Q.number . T.postingBox $ p of
      Nothing -> Nothing
      (Just num) ->
        Just
        . T.ClaimedWidth
        . X.length
        . text
        $ num

sNumber :: ((Col, Row), Claimer a)
sNumber = ((Adr.SNum, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.flag opts
    . claimOneIf
    . isJust
    . Q.number
    . T.postingBox
    $ p

payee :: ((Col, Row), Claimer a)
payee = ((Adr.Payee, Adr.Top), noClaim)

sPayee :: ((Col, Row), Claimer a)
sPayee = ((Adr.SPayee, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.payee opts
    . claimOneIf
    . isJust
    . Q.payee
    . T.postingBox
    $ p

account :: ((Col, Row), Claimer a)
account = ((Adr.Account, Adr.Top), noClaim)

sAccount :: ((Col, Row), Claimer a)
sAccount = ((Adr.SAccount, Adr.Top), f) where
  f opts _ _ _ = ifShown F.account opts claimOne

postingDrCr :: ((Col, Row), Claimer a)
postingDrCr = ((Adr.PostingDrCr, Adr.Top), f) where
  f opts _ _ _ = ifShown F.postingDrCr opts $
                   Just (T.ClaimedWidth 2)

sPostingDrCr :: ((Col, Row), Claimer a)
sPostingDrCr = ((Adr.SPostingDrCr, Adr.Top), f) where
  f opts _ _ _ =
    ifShown F.postingDrCr opts claimOne

postingCmdty :: ((Col, Row), Claimer a)
postingCmdty = ((Adr.PostingCommodity, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.postingCmdty opts $
    Just
    . T.ClaimedWidth
    . X.length
    . text
    . HT.Delimited (X.singleton ':')
    . HT.textList
    . Q.commodity
    . T.postingBox
    $ p

sPostingCmdty :: ((Col, Row), Claimer a)
sPostingCmdty = ((Adr.SPostingCommodity, Adr.Top), f) where
  f opts _ _ _ = ifShown F.postingCmdty opts claimOne

postingQty :: ((Col, Row), Claimer a)    
postingQty = ((Adr.PostingQty, Adr.Top), f) where
  f opts _ _ p =
    ifShown F.postingQty opts $
    Just
    . T.ClaimedWidth
    . X.length
    . O.qtyFormat opts
    $ p

sPostingQty :: ((Col, Row), Claimer a)
sPostingQty = ((Adr.SPostingQty, Adr.Top), f) where
  f opts _ _ _ = ifShown F.postingQty opts claimOne

totalDrCr :: ((Col, Row), Claimer a)
totalDrCr = ((Adr.TotalDrCr, Adr.Top), f) where
  f opts _ _ _ =
    ifShown F.totalDrCr opts
    $ Just
    . T.ClaimedWidth
    $ 2

sTotalDrCr :: ((Col, Row), Claimer a)
sTotalDrCr = ((Adr.STotalDrCr, Adr.Top), f) where
  f opts _ _ _ = ifShown F.totalDrCr opts claimOne


totalCmdty :: ((Col, Row), Claimer a)
totalCmdty = ((Adr.TotalCommodity, Adr.Top), f) where
  f opts _ _ p = ifShown F.totalCmdty opts (Just widest) where
    balMap = Bal.unBalance . T.balance $ p
    widest = M.foldrWithKey folder (T.ClaimedWidth 0) balMap where
      folder com _ soFar = max width soFar where
        width = T.ClaimedWidth
                . X.length
                . text
                . HT.Delimited (X.singleton ':')
                . HT.textList
                $ com

sTotalCmdty :: ((Col, Row), Claimer a)
sTotalCmdty = ((Adr.STotalCommodity, Adr.Top), f) where
  f opts _ _ _ = ifShown F.totalCmdty opts claimOne

totalQty :: ((Col, Row), Claimer a)
totalQty = ((Adr.TotalQty, Adr.Top), f) where
  f opts _ _ p = ifShown F.totalQty opts (Just widest) where
    balMap = Bal.unBalance . T.balance $ p
    widest = M.foldrWithKey folder (T.ClaimedWidth 0) balMap where
      folder com no soFar = max width soFar where
        width = T.ClaimedWidth
                . X.length
                . O.balanceFormat opts com
                $ no
