-- | Payee parsers. There are two types of payee parsers:
--
-- Quoted payees. These allow the most latitude in the characters
-- allowed. They are surrounded by @<@ and @>@.
--
-- Unquoted payees. These are not surrounded by @<@ and @>@. Their
-- first character must be a letter or number.

module Penny.Copper.Payees (
  -- * Parse any payee
  payee
  
  -- * Quoted payees
  , quotedChar
  , quotedPayee
    
    -- * Unquoted payees
  , unquotedFirstChar
  , unquotedRestChars
  , unquotedPayee
    
    -- * Rendering
  , smartRender
  , quoteRender
  ) where

import Control.Applicative ((<$>), (<*>), (<|>))
import qualified Data.Char as C
import qualified Data.List.NonEmpty as NE
import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Text (pack, Text, snoc, cons)
import qualified Data.Text as X
import Text.Parsec (char, satisfy, many, between, (<?>))
import Text.Parsec.Text ( Parser )

import Penny.Copper.Util (inCat, checkText)
import qualified Penny.Lincoln.Bits as B
import Penny.Lincoln.TextNonEmpty ( TextNonEmpty ( TextNonEmpty ) )
import Penny.Lincoln.TextNonEmpty as TNE

quotedChar :: Char -> Bool
quotedChar c = allowed && not banned where
  allowed = inCat C.UppercaseLetter C.OtherSymbol c ||
            c == ' '
  banned = c == '>'

payee :: Parser B.Payee
payee = quotedPayee <|> unquotedPayee

quotedPayee :: Parser B.Payee
quotedPayee = between (char '<') (char '>') p <?> "quoted payee" where
  p = (\c cs -> B.Payee (TextNonEmpty c (pack cs)))
      <$> satisfy quotedChar
      <*> many (satisfy quotedChar)

unquotedFirstChar :: Char -> Bool
unquotedFirstChar = inCat C.UppercaseLetter C.OtherLetter

unquotedRestChars :: Char -> Bool
unquotedRestChars c = inCat C.UppercaseLetter C.OtherSymbol c
                      || c == ' '

unquotedPayee :: Parser B.Payee
unquotedPayee = let
  p c cs = B.Payee (TextNonEmpty c (pack cs))
  in p
     <$> satisfy unquotedFirstChar
     <*> many (satisfy unquotedRestChars)
     <?> "unquoted payee"

-- | Render a payee with a minimum of quoting. Fails if cannot be
-- rendered at all.
smartRender :: B.Payee -> Maybe Text
smartRender (B.Payee p) = let
  TextNonEmpty first rest = p
  noQuoteNeeded = unquotedFirstChar first
                  && X.all unquotedRestChars rest
  renderable = TNE.all quotedChar p
  quoted = '<' `cons` TNE.toText p `snoc` '>'
  makeText
    | noQuoteNeeded = Just $ TNE.toText p
    | renderable = Just quoted
    | otherwise = Nothing
  in makeText

-- | Renders with quotes, whether the payee needs it or not.
quoteRender :: B.Payee -> Maybe Text
quoteRender (B.Payee p) = let
  renderable = TNE.all quotedChar p
  quoted = '<' `cons` TNE.toText p `snoc` '>'
  in if renderable
     then Just quoted
     else Nothing
