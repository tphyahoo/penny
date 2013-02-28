{-# LANGUAGE OverloadedStrings #-}

-- | Functions that return a boolean based upon some criterion that
-- matches something, often a PostFam. Useful when filtering
-- Postings.
module Penny.Lincoln.Predicates where


import Data.List (intersperse)
import Data.Monoid ((<>))
import Data.Text (Text)
import qualified Data.Text as X
import Data.Time (Day)
import qualified Penny.Lincoln.Bits as B
import Penny.Lincoln.HasText (HasText, text, HasTextList, textList)
import qualified Penny.Lincoln.Family.Family as F
import qualified Penny.Lincoln.Queries as Q
import Penny.Lincoln.Transaction (PostFam)
import qualified Penny.Lincoln.Transaction as T
import qualified Text.Matchers as M

-- | Predicates also come with a description, which is useful for
-- giving diagnostics to the user.
data Pdct = Pdct
  { pdct :: PostFam -> Bool
  , description :: Text
  }

type MakePdct = M.Matcher -> Pdct

-- * Matching helpers
match
  :: HasText a
  => Text
  -- ^ Description of this field
  -> (PostFam -> a)
  -- ^ Function that returns the field being matched
  -> M.Matcher
  -> Pdct
match t f m = Pdct pd desc
  where
    desc = makeDesc t m
    pd = M.match m . text . f

matchMaybe
  :: HasText a
  => Text
  -- ^ Description of this field
  -> (PostFam -> Maybe a)
  -> M.Matcher
  -> Pdct
matchMaybe t f m = Pdct pd desc
  where
    desc = makeDesc t m
    pd = maybe False (M.match m . text) . f

makeDesc :: Text -> M.Matcher -> Text
makeDesc t m
  = "subject: " <> t
  <> " matcher: " <> M.matchDesc m

-- | Does the given matcher match any of the elements of the Texts in
-- a HasTextList?
matchAny
  :: HasTextList a
  => Text
  -> (PostFam -> a)
  -> M.Matcher
  -> Pdct
matchAny t f m = Pdct pd desc
  where
    desc = makeDesc ("any of the components of " <> t) m
    pd = any (M.match m) . textList . f

matchAnyMaybe
  :: HasTextList a
  => Text
  -> (PostFam -> Maybe a)
  -> M.Matcher
  -> Pdct
matchAnyMaybe t f m = Pdct pd desc
  where
    desc = makeDesc ("any of the components of " <> t) m
    pd = maybe False (any (M.match m) . textList) . f

-- | Does the given matcher match the text that is at the given
-- element of a HasTextList? If the HasTextList does not have a
-- sufficent number of elements to perform this test, returns False.
matchLevel
  :: HasTextList a
  => Int
  -> Text
  -> (PostFam -> a)
  -> M.Matcher
  -> Pdct
matchLevel l d f m = Pdct pd desc
  where
    desc = makeDesc ("level " <> X.pack (show l) <> " of " <> d) m
    pd pf = let ts = textList (f pf)
            in if l < 0 || l >= length ts
               then False
               else M.match m (ts !! l)

matchMaybeLevel
  :: HasTextList a
  => Int
  -> Text
  -> (PostFam -> Maybe a)
  -> M.Matcher
  -> Pdct
matchMaybeLevel l d f m = Pdct pd desc
  where
    desc = makeDesc ("level " <> X.pack (show l) <> " of " <> d) m
    doMatch a = let ts = textList a
                in if l < 0 || l >= length ts
                   then False
                   else M.match m (ts !! l)
    pd = maybe False doMatch . f

-- | Does the matcher match the text of the memo? Joins each line of
-- the memo with a space.
matchMemo
  :: Text
  -> (PostFam -> Maybe B.Memo)
  -> M.Matcher
  -> Pdct
matchMemo t f m = Pdct pd desc
  where
    desc = makeDesc t m
    pd = maybe False doMatch . f
    doMatch = M.match m
              . X.intercalate (X.singleton ' ')
              . B.unMemo



-- * Matching helpers

{-
match :: HasText a => (Text -> Bool) -> a -> Bool
match f = f . text

matchMaybe :: HasText a => (Text -> Bool) -> Maybe a -> Bool
matchMaybe f = maybe False (match f)


matchAny :: HasTextList a => (Text -> Bool) -> a -> Bool
matchAny f = any f . textList

matchAnyMaybe :: HasTextList a => (Text -> Bool) -> Maybe a -> Bool
matchAnyMaybe f = maybe False (matchAny f)


-- | Does the given matcher match the text that is at the given
-- element of a HasTextList? If the HasTextList does not have a
-- sufficent number of elements to perform this test, returns False.
matchLevel :: HasTextList a => Int -> (Text -> Bool) -> a -> Bool
matchLevel i f a = let ts = textList a in
  if i < 0 || i >= length ts
  then False
  else f (ts !! i)

-- | Does the matcher match the text of the memo? Joins each line of
-- the memo with a space.
matchMemo :: (Text -> Bool) -> Maybe B.Memo -> Bool
matchMemo f = maybe False (f . X.intercalate (X.singleton ' ') . B.unMemo)


matchMaybeLevel ::
  HasTextList a
  => Int
  -> (Text -> Bool)
  -> Maybe a
  -> Bool
matchMaybeLevel i f = maybe False (matchLevel i f)


-- * Pattern matching fields

payee :: (Text -> Bool) -> PostFam -> Bool
payee f = matchMaybe f . Q.payee

number :: (Text -> Bool) -> PostFam -> Bool
number f = matchMaybe f . Q.number

flag :: (Text -> Bool) -> PostFam -> Bool
flag f = matchMaybe f . Q.flag

postingMemo :: (Text -> Bool) -> PostFam -> Bool
postingMemo f = matchMemo f . Q.postingMemo

transactionMemo :: (Text -> Bool) -> PostFam -> Bool
transactionMemo f = matchMemo f . Q.transactionMemo

-- * Date

date ::
  (B.DateTime -> Bool)
  -> PostFam
  -> Bool
date f c = f (Q.dateTime c)


localDay ::
  (Day -> Bool)
  -> PostFam
  -> Bool
localDay f = f . Q.localDay

-- * Qty

qty ::
  (B.Qty -> Bool)
  -> PostFam
  -> Bool
qty f c = f (Q.qty c)


-- * DrCr
drCr :: B.DrCr -> PostFam -> Bool
drCr dc p = dc == Q.drCr p

debit :: PostFam -> Bool
debit p = Q.drCr p == B.Debit

credit :: PostFam -> Bool
credit p = Q.drCr p == B.Credit

-- * Matching delimited fields

matchDelimited ::
  HasTextList a
  => Text
  -> (Text -> Bool)
  -> a -> Bool
matchDelimited d f = f . X.concat . intersperse d . textList

-- * Commodity

commodity :: (Text -> Bool) -> PostFam -> Bool
commodity f = f . text . Q.commodity


-- * Account
account :: Text -> (Text -> Bool) -> PostFam -> Bool
account t f = matchDelimited t f . Q.account

accountLevel :: Int -> (Text -> Bool) -> PostFam -> Bool
accountLevel i f = matchLevel i f . Q.account

accountAny :: (Text -> Bool) -> PostFam -> Bool
accountAny f = matchAny f . Q.account

-- * Tags
tag :: (Text -> Bool) -> PostFam -> Bool
tag f = matchAny f . Q.tags

-- * Combining predicates
(&&&) :: (a -> Bool) -> (a -> Bool) -> (a -> Bool)
(&&&) l r = \a -> l a && r a

infixr 3 &&&

(|||) :: (a -> Bool) -> (a -> Bool) -> (a -> Bool)
(|||) l r = \a -> l a || r a

infixr 2 |||


-- * Clones

-- | Returns True if these two transactions are clones; that is, if
-- they are identical in all respects except some aspects of their
-- metadata. The metadata that is disregarded when testing for clones
-- pertains to the location of the transaction. (Resembles cloned
-- sheep, which are identical but cannot be in exactly the same
-- place.)
clonedTransactions :: T.Transaction -> T.Transaction -> Bool
clonedTransactions a b =
  let (F.Family ta p1a p2a psa) = T.unTransaction a
      (F.Family tb p1b p2b psb) = T.unTransaction b
  in clonedTopLines ta tb
     && clonedPostings p1a p1b
     && clonedPostings p2a p2b
     && (length psa == length psb)
     && (and (zipWith clonedPostings psa psb))

-- | Returns True if two TopLines are clones. Considers only the
-- non-metadata aspects of the TopLine; the metadata all pertains only
-- to the location of the TopLine. The DateTimes are compared based on
-- both the local time and the time zone; that is, two times that
-- refer to the same instant will not compare as identical if they
-- have different time zones.
clonedTopLines :: T.TopLine -> T.TopLine -> Bool
clonedTopLines t1 t2 =
  (T.tDateTime t1 == T.tDateTime t2)
  && (T.tFlag t1 == T.tFlag t2)
  && (T.tNumber t1 == T.tNumber t2)
  && (T.tPayee t2 == T.tPayee t2)
  && (T.tMemo t1 == T.tMemo t2)

-- | Returns True if two Postings are clones. Considers only the
-- non-location-related aspects of the posting metadata.
clonedPostings :: T.Posting -> T.Posting -> Bool
clonedPostings p1 p2 =
  (T.pPayee p1 == T.pPayee p2)
  && (T.pNumber p1 == T.pNumber p2)
  && (T.pFlag p1 == T.pFlag p2)
  && (T.pAccount p1 == T.pAccount p2)
  && (T.pTags p1 == T.pTags p2)
  && (T.pEntry p1 == T.pEntry p2)
  && (T.pMemo p1 == T.pMemo p2)
  && (T.pInferred p1 == T.pInferred p2)
-}
