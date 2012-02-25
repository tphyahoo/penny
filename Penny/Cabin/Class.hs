module Penny.Cabin.Class where

import Control.Monad.Exception.Synchronous (Exceptional)
import Data.Text (Text)
import System.Console.MultiArg.Prim (ParserE)

import Penny.Cabin.Colors (Chunk, Colors)
import Penny.Liberty.Error (Error)
import Penny.Lincoln.Bits (DateTime)
import Penny.Lincoln.Boxes (  PostingBox, PriceBox )

import Text.Matchers.Text (CaseSensitive)

type ReportFunc =
  Context
  -> [PostingBox]
  -> [PriceBox]
  -> Exceptional Text Chunk

-- | The parser must parse everything beginning with its command name
-- (parser must fail without consuming any input if the next word is
-- not its command name) up until, but not including, the first
-- non-option word.
type ParseReportOpts =
  CaseSensitive
  -> (Text -> Exceptional Text (Text -> Bool))
  -> ParserE Error (ReportFunc, Colors)

data Report =
  Report { help :: Text
         , printReport :: ParseReportOpts }

data Context =
  Context { lines :: Maybe Lines
          , columns :: Maybe Columns
          , currentTime :: DateTime }

data Columns = Columns { unColumns :: Int }
               deriving Show

data Lines = Lines { unLines :: Int }
             deriving Show
