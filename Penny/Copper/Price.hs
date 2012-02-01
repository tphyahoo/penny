module Penny.Parser.Price where

import Control.Monad ( void )
import Text.Parsec ( char, many )
import Text.Parsec.Text ( Parser )

import qualified Penny.Bits.Amount as Amount
import qualified Penny.Bits.Price as P
import qualified Penny.Bits.PricePoint as PP
import qualified Penny.Parser.Amount as A
import qualified Penny.Parser.Commodity as C
import qualified Penny.Parser.DateTime as DT
import qualified Penny.Parser.Price.Data as Data
import qualified Penny.Parser.Qty as Q

whitespace :: Parser ()
whitespace = void (many (char ' '))

price ::
  DT.DefaultTimeZone
  -> Q.Radix
  -> Q.Separator
  -> Parser Data.Data
price dtz rad sep = do
  void $ char 'P'
  whitespace
  dt <- DT.dateTime dtz
  whitespace
  com <- C.commodityWithDigits
  whitespace
  (amt, pair) <- A.amount rad sep
  let (from, to) = (P.From com, P.To (Amount.commodity amt))
      cpu = P.CountPerUnit (Amount.qty amt)
  pr <- case P.price from to cpu of
    (Just pri) -> return pri
    Nothing -> fail "invalid price given"
  return $ Data.Data (PP.PricePoint dt pr) pair