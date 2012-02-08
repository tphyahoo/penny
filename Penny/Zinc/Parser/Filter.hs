module Penny.Zinc.Parser.Filter where

import Control.Monad.Exception.Synchronous (
  Exceptional(Exception, Success))
import Data.Monoid (mempty)
import Data.Monoid.Extra (Orderer)
import Data.Text (Text, pack, unpack)
import System.Console.MultiArg.Combinator
  (mixedNoArg, mixedOneArg, longOneArg, longNoArg, longTwoArg)
import System.Console.MultiArg.Option (makeLongOpt, makeShortOpt)
import qualified System.Console.MultiArg.Error as E
import System.Console.MultiArg.Prim (ParserE, throw)
import qualified Text.Matchers.Text as M
import Text.Parsec (parse)

import Penny.Copper.DateTime (DefaultTimeZone, dateTime)
import Penny.Copper.Qty (Radix, Separator, qty)

import qualified Penny.Lincoln.Predicates as P
import Penny.Lincoln.Bits (DateTime, Qty)
import Penny.Lincoln.Boxes (PostingBox)
import qualified Penny.Zinc.Expressions as X

data Error = MultiArgError E.Expecting E.Saw
             | MakeMatcherFactoryError Text
             | DateParseError
             | BadPatternError Text
             | BadNumberError Text
             | BadQtyError Text
             deriving Show

instance E.Error Error where
  parseErr = MultiArgError

data State t p =
  State { sensitive :: M.CaseSensitive
        , matcher :: Text -> Exceptional Text (Text -> Bool)
        , tokens :: [X.Token (PostingBox t p -> Bool)]
        , sorter :: Orderer
                    (PostingBox t p -> PostingBox t p -> Ordering) }

blankState :: State t p
blankState = State { sensitive = M.Insensitive
                   , matcher = return . M.within M.Insensitive
                   , tokens = mempty
                   , sorter = mempty }

addOperand :: (PostingBox t p -> Bool) -> State t p -> State t p
addOperand f s = s { tokens = tokens s ++ [X.TokOperand f] }

before :: DefaultTimeZone -> State t p -> ParserE Error (State t p)
before dtz s = do
  let lo = makeLongOpt . pack $ "before"
  (_, t) <- mixedOneArg lo [] []
  dt <- parseDate dtz t
  return $ addOperand (P.before dt) s

after :: DefaultTimeZone -> State t p -> ParserE Error (State t p)
after dtz s = do
  let lo = makeLongOpt . pack $ "after"
  (_, t) <- longOneArg lo
  d <- parseDate dtz t
  return $ addOperand (P.after d) s

onOrBefore :: DefaultTimeZone -> State t p -> ParserE Error (State t p)
onOrBefore dtz s = do
  let lo = makeLongOpt . pack $ "on-or-before"
      so = makeShortOpt 'b'
  (_, t) <- mixedOneArg lo [] [so]
  d <- parseDate dtz t
  return $ addOperand (P.onOrBefore d) s

onOrAfter :: DefaultTimeZone -> State t p -> ParserE Error (State t p)
onOrAfter dtz s = do
  let lo = makeLongOpt . pack $ "on-or-after"
      so = makeShortOpt 'a'
  (_, t) <- mixedOneArg lo [] [so]
  d <- parseDate dtz t
  return $ addOperand (P.onOrAfter d) s
  
dayEquals :: DefaultTimeZone -> State t p -> ParserE Error (State t p)
dayEquals dtz s = do
  let lo = makeLongOpt . pack $ "day-equals"
  (_, t) <- longOneArg lo
  d <- parseDate dtz t
  return $ addOperand (P.dateIs d) s

current :: DateTime -> State t p -> ParserE Error (State t p)
current dt s = do
  let lo = makeLongOpt . pack $ "current"
  _ <- longNoArg lo
  return $ addOperand (P.onOrBefore dt) s

parseDate :: DefaultTimeZone -> Text -> ParserE Error DateTime
parseDate dtz t = case parse (dateTime dtz) "" t of
  Left _ -> throw DateParseError
  Right d -> return d

--
-- Pattern matching
--

getMatcher :: Text -> State t p -> ParserE Error (Text -> Bool)
getMatcher t s = case matcher s t of
  Exception e -> throw $ BadPatternError e
  Success m -> return m

sep :: Text
sep = pack ":"

sepOption ::
  String
  -> Maybe Char
  -> (Text -> (Text -> Bool) -> PostingBox t p -> Bool)
  -> State t p
  -> ParserE Error (State t p)
sepOption str mc f s = do
  let lo = makeLongOpt . pack $ str
  (_, p) <- mixedOneArg lo [] $ case mc of
    Nothing -> []
    (Just c) -> [makeShortOpt c]
  m <- getMatcher p s
  return $ addOperand (f sep m) s

account :: State t p -> ParserE Error (State t p)
account = sepOption "account" (Just 'A') P.account

parseInt :: Text -> ParserE Error Int
parseInt t = let ps = reads . unpack $ t in
  case ps of
    [] -> throw $ BadNumberError t
    ((i, s):[]) -> if length s /= 0
                   then throw $ BadNumberError t
                   else return i
    _ -> throw $ BadNumberError t

levelOption ::
  String
  -> (Int -> (Text -> Bool) -> PostingBox t p -> Bool)
  -> State t p
  -> ParserE Error (State t p)
levelOption str f s = do
  let lo = makeLongOpt . pack $ str
  (_, ns, p) <- longTwoArg lo
  n <- parseInt ns
  m <- getMatcher p s
  return $ addOperand (f n m) s

accountLevel :: State t p -> ParserE Error (State t p)
accountLevel = levelOption "account-level" P.accountLevel

accountAny :: State t p -> ParserE Error (State t p)
accountAny = patternOption "account-any" Nothing P.accountAny

payee :: State t p -> ParserE Error (State t p)
payee = patternOption "payee" (Just 'p') P.payee

patternOption ::
  String -- ^ Long option
  -> Maybe Char -- ^ Short option
  -> ((Text -> Bool) -> PostingBox t p -> Bool) -- ^ Predicate maker
  -> State t p
  -> ParserE Error (State t p)
patternOption str mc f s = do
  let lo = makeLongOpt . pack $ str
  (_, p) <- mixedOneArg lo [] $ case mc of
    (Just c) -> [makeShortOpt c]
    Nothing -> []
  m <- getMatcher p s
  return $ addOperand (f m) s

tag :: State t p -> ParserE Error (State t p)
tag = patternOption "tag" (Just 't') P.tag

number :: State t p -> ParserE Error (State t p)
number = patternOption "number" Nothing P.number

flag :: State t p -> ParserE Error (State t p)
flag = patternOption "flag" Nothing P.flag

commodity :: State t p -> ParserE Error (State t p)
commodity = sepOption "commodity" Nothing P.commodity

commodityLevel :: State t p -> ParserE Error (State t p)
commodityLevel = levelOption "commodity-level" P.commodityLevel

commodityAny :: State t p -> ParserE Error (State t p)
commodityAny = patternOption "commodity" Nothing P.commodityAny


postingMemo :: State t p -> ParserE Error (State t p)
postingMemo = patternOption "posting-memo" Nothing P.postingMemo

transactionMemo :: State t p -> ParserE Error (State t p)
transactionMemo = patternOption "transaction-memo"
                  Nothing P.transactionMemo

noFlag :: State t p -> ParserE Error (State t p)
noFlag = return . addOperand P.noFlag

debit :: State t p -> ParserE Error (State t p)
debit = return . addOperand P.debit

credit :: State t p -> ParserE Error (State t p)
credit = return . addOperand P.credit

qtyOption ::
  String
  -> (Qty -> PostingBox t p -> Bool)
  -> Radix
  -> Separator
  -> State t p
  -> ParserE Error (State t p)
qtyOption str f rad sp s = do
  let lo = makeLongOpt . pack $ str
  (_, qs) <- longOneArg lo
  case parse (qty rad sp) "" qs of
    Left _ -> throw $ BadQtyError qs
    Right qt -> return $ addOperand (f qt) s

atLeast ::
  Radix
  -> Separator
  -> State t p
  -> ParserE Error (State t p)
atLeast = qtyOption "at-least" P.greaterThanOrEqualTo

lessThan ::
  Radix
  -> Separator
  -> State t p
  -> ParserE Error (State t p)
lessThan = qtyOption "less-than" P.lessThan

equals ::
  Radix
  -> Separator
  -> State t p
  -> ParserE Error (State t p)
equals = qtyOption "equals" P.equals

changeState ::
  String
  -> Maybe Char
  -> (State t p -> State t p)
  -> State t p
  -> ParserE Error (State t p)
changeState str mc f s = do
  let lo = makeLongOpt . pack $ str
      so = case mc of
        Nothing -> []
        Just c -> [makeShortOpt c]
  _ <- mixedNoArg lo [] so
  return $ f s


caseInsensitive :: State t p -> ParserE Error (State t p)
caseInsensitive = changeState "case-insensitive" (Just 'i') f where
  f st = st { sensitive = M.Insensitive }

caseSensitive :: State t p -> ParserE Error (State t p)
caseSensitive = changeState "case-sensitive" (Just 'I') f where
  f st = st { sensitive = M.Sensitive }

within :: State t p -> ParserE Error (State t p)
within = changeState "within" Nothing f where
  f st = st { matcher = \t -> return (M.within (sensitive st) t) }

pcre :: State t p -> ParserE Error (State t p)
pcre = changeState "pcre" Nothing f where
  f st = st { matcher = M.pcre (sensitive st) }

posix :: State t p -> ParserE Error (State t p)
posix = changeState "posix" Nothing f where
  f st = st { matcher = M.tdfa (sensitive st) }

exact :: State t p -> ParserE Error (State t p)
exact = changeState "exact" Nothing f where
  f st = st { matcher = \t -> return (M.exact (sensitive st) t) }

