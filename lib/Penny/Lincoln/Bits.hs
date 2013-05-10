{-# LANGUAGE DeriveGeneric, CPP #-}

-- | Essential data types used to make Transactions and Postings.
module Penny.Lincoln.Bits
  ( module Penny.Lincoln.Bits.Open
  , module Penny.Lincoln.Bits.DateTime
  , module Penny.Lincoln.Bits.Price
  , module Penny.Lincoln.Bits.Qty
  , PricePoint ( .. )

  -- * Aggregates
  , TopLineCore(..)
  , emptyTopLineCore
  , TopLineFileMeta(..)
  , TopLineData(..)
  , emptyTopLineData
  , PostingCore(..)
  , emptyPostingCore
  , PostingFileMeta(..)
  , PostingData(..)
  , emptyPostingData

#ifdef test
  , tests
#endif
  ) where


import Data.Monoid (mconcat)
import Penny.Lincoln.Bits.Open
import Penny.Lincoln.Bits.DateTime
import Penny.Lincoln.Bits.Price
#ifdef test
import Penny.Lincoln.Bits.Qty hiding (tests)
#else
import Penny.Lincoln.Bits.Qty
#endif

import qualified Penny.Lincoln.Bits.Open as O
import qualified Penny.Lincoln.Bits.DateTime as DT
import qualified Penny.Lincoln.Bits.Price as Pr
import qualified Penny.Lincoln.Equivalent as Ev
import Penny.Lincoln.Equivalent ((==~))
import qualified Data.Binary as B
import GHC.Generics (Generic)

#ifdef test
import Control.Monad (liftM4, liftM2, liftM3, liftM5)
import Control.Applicative ((<$>), (<*>))
import Test.QuickCheck (Arbitrary, arbitrary)
import Test.Framework (Test, testGroup)
import qualified Penny.Lincoln.Bits.Qty as Q
#endif

data PricePoint = PricePoint { dateTime :: DT.DateTime
                             , price :: Pr.Price
                             , ppSide :: Maybe O.Side
                             , ppSpaceBetween :: Maybe O.SpaceBetween
                             , priceLine :: Maybe O.PriceLine }
                  deriving (Eq, Show, Generic)

instance B.Binary PricePoint

-- | PricePoint are equivalent if the dateTime and the Price are
-- equivalent. Other elements of the PricePoint are ignored.
instance Ev.Equivalent PricePoint where
  equivalent (PricePoint dx px _ _ _) (PricePoint dy py _ _ _) =
    dx ==~ dy && px ==~ py
  compareEv (PricePoint dx px _ _ _) (PricePoint dy py _ _ _) =
    mconcat [ Ev.compareEv dx dy
            , Ev.compareEv px py ]

-- | All the data that a TopLine might have.
data TopLineData = TopLineData
  { tlCore :: TopLineCore
  , tlFileMeta :: Maybe TopLineFileMeta
  , tlGlobal :: Maybe O.GlobalTransaction
  } deriving (Eq, Show, Generic)

emptyTopLineData :: DT.DateTime -> TopLineData
emptyTopLineData dt = TopLineData (emptyTopLineCore dt) Nothing Nothing

instance B.Binary TopLineData

#ifdef test
instance Arbitrary TopLineData where
  arbitrary = liftM3 TopLineData arbitrary arbitrary arbitrary
#endif

-- | Every TopLine has this data.
data TopLineCore = TopLineCore
  { tDateTime :: DT.DateTime
  , tNumber :: Maybe O.Number
  , tFlag :: Maybe O.Flag
  , tPayee :: Maybe O.Payee
  , tMemo :: Maybe O.Memo
  } deriving (Eq, Show, Generic)

-- | TopLineCore are equivalent if their dates are equivalent and if
-- everything else is equal.
instance Ev.Equivalent TopLineCore where
  equivalent x y =
    tDateTime x ==~ tDateTime y
    && tNumber x == tNumber y
    && tFlag x == tFlag y
    && tPayee x == tPayee y
    && tMemo x == tMemo y

  compareEv x y = mconcat
    [ Ev.compareEv (tDateTime x) (tDateTime y)
    , compare (tNumber x) (tNumber y)
    , compare (tFlag x) (tFlag y)
    , compare (tPayee x) (tPayee y)
    , compare (tMemo x) (tMemo y)
    ]

emptyTopLineCore :: DT.DateTime -> TopLineCore
emptyTopLineCore dt = TopLineCore dt Nothing Nothing Nothing Nothing

instance B.Binary TopLineCore

#ifdef test
instance Arbitrary TopLineCore where
  arbitrary = liftM5 TopLineCore arbitrary arbitrary arbitrary
              arbitrary arbitrary
#endif

-- | TopLines from files have this metadata.
data TopLineFileMeta = TopLineFileMeta
  { tFilename :: O.Filename
  , tTopLineLine :: O.TopLineLine
  , tTopMemoLine :: Maybe O.TopMemoLine
  , tFileTransaction :: O.FileTransaction
  } deriving (Eq, Show, Generic)

instance B.Binary TopLineFileMeta


#ifdef test
instance Arbitrary TopLineFileMeta where
  arbitrary = liftM4 TopLineFileMeta arbitrary arbitrary
              arbitrary arbitrary
#endif

-- | All Postings have this data.
data PostingCore = PostingCore
  { pPayee :: Maybe O.Payee
  , pNumber :: Maybe O.Number
  , pFlag :: Maybe O.Flag
  , pAccount :: O.Account
  , pTags :: O.Tags
  , pMemo :: Maybe O.Memo
  , pSide :: Maybe O.Side
  , pSpaceBetween :: Maybe O.SpaceBetween
  } deriving (Eq, Show, Generic)

-- | Two PostingCore are equivalent if the Tags are equivalent and the
-- other data is equal, exlucing the Side and the SpaceBetween, which are not considered at all.
instance Ev.Equivalent PostingCore where
  equivalent (PostingCore p1 n1 f1 a1 t1 m1 _ _)
             (PostingCore p2 n2 f2 a2 t2 m2 _ _)
    = p1 == p2 && n1 == n2 && f1 == f2
    && a1 == a2 && t1 ==~ t2 && m1 == m2

  compareEv (PostingCore p1 n1 f1 a1 t1 m1 _ _)
            (PostingCore p2 n2 f2 a2 t2 m2 _ _)
    = mconcat
        [ compare p1 p2
        , compare n1 n2
        , compare f1 f2
        , compare a1 a2
        , Ev.compareEv t1 t2
        , compare m1 m2
        ]

emptyPostingCore :: O.Account -> PostingCore
emptyPostingCore ac = PostingCore
  { pPayee = Nothing
  , pNumber = Nothing
  , pFlag = Nothing
  , pAccount = ac
  , pTags = O.Tags []
  , pMemo = Nothing
  , pSide = Nothing
  , pSpaceBetween = Nothing
  }

instance B.Binary PostingCore

#ifdef test
instance Arbitrary PostingCore where
  arbitrary = PostingCore <$> arbitrary <*> arbitrary <*> arbitrary
              <*> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary
              <*> arbitrary
#endif

-- | Postings from files have this additional data.
data PostingFileMeta = PostingFileMeta
  { pPostingLine :: O.PostingLine
  , pFilePosting :: O.FilePosting
  } deriving (Eq, Show, Generic)

instance B.Binary PostingFileMeta

#ifdef test
instance Arbitrary PostingFileMeta where
  arbitrary = liftM2 PostingFileMeta arbitrary arbitrary
#endif

-- | All the data that a Posting might have.
data PostingData = PostingData
  { pdCore :: PostingCore
  , pdFileMeta :: Maybe PostingFileMeta
  , pdGlobal :: Maybe O.GlobalPosting
  } deriving (Eq, Show, Generic)

emptyPostingData :: O.Account -> PostingData
emptyPostingData ac = PostingData
  { pdCore = emptyPostingCore ac
  , pdFileMeta = Nothing
  , pdGlobal = Nothing
  }

instance B.Binary PostingData

#ifdef test
instance Arbitrary PostingData where
  arbitrary = liftM3 PostingData arbitrary arbitrary arbitrary

tests :: Test
tests = testGroup "Penny.Lincoln.Bits"
  [ Q.tests
  ]

#endif

