module Penny.Lincoln.Family where

import qualified Penny.Lincoln.Family.Family as F
import qualified Penny.Lincoln.Family.Child as C
import qualified Penny.Lincoln.Family.Siblings as S

children :: F.Family p c -> S.Siblings (C.Child p c)
children (F.Family p c1 c2 cRest) = S.Siblings fc sc rc where
  fc = C.Child c1 c2 cRest p
  sc = C.Child c2 c1 cRest p
  rc = map toChild rest
  rest = S.others cRest
  toChild (c, cs) = C.Child c c1 (c2:cs) p

orphans :: F.Family p c -> S.Siblings c
orphans (F.Family _ c1 c2 cs) = S.Siblings c1 c2 cs

adopt :: p -> S.Siblings c -> F.Family p c
adopt p (S.Siblings c1 c2 cs) = F.Family p c1 c2 cs

mergeWith :: (p1 -> p2 -> p3)
             -> (c1 -> c2 -> c3)
             -> F.Family p1 c1
             -> F.Family p2 c2
             -> F.Family p3 c3
mergeWith fp fc (F.Family lp lc1 lc2 lcs) (F.Family rp rc1 rc2 rcs) =
  F.Family (fp lp rp) (fc lc1 rc1) (fc lc2 rc2)
  (zipWith fc lcs rcs)

merge :: F.Family p1 c1
         -> F.Family p2 c2
         -> F.Family (p1, p2) (c1, c2)
merge = mergeWith (,) (,)
  
  
  