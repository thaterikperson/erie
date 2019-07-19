Definitions.
Digit      = [0-9]
Upper      = [A-Z]
Alpha      = [A-Za-z\._!\+]
DigitOrAlpha = ({Digit}|{Alpha})
Whitespace = [\n\t\s,]

Rules.

\(                 : {token, {'(',  TokenLine}}.
\)                 : {token, {')',  TokenLine}}.
\[                 : {token, {'[',  TokenLine}}.
\]                 : {token, {']',  TokenLine}}.
\{                 : {token, {'{',  TokenLine}}.
\}                 : {token, {'}',  TokenLine}}.
\".*\"             : {token, {string, TokenLine, string_to_binary(TokenChars)}}.
{Digit}+\.{Digit}+ : {token, {float, TokenLine, TokenChars}}.
{Digit}+           : {token, {integer, TokenLine, list_to_integer(TokenChars)}}.
'{Alpha}+          : {token, {symbol, TokenLine, symbol_to_atom(TokenChars)}}.
{Upper}{DigitOrAlpha}*    : {token, {symbol, TokenLine, list_to_atom(TokenChars)}}.
{Alpha}+           : {token, {atom, TokenLine, list_to_atom(TokenChars)}}.
{Whitespace}+      : skip_token.

Erlang code.

symbol_to_atom([$'|Chars]) ->
    list_to_atom(Chars).

string_to_binary([$"|Chars]) ->
    [$"|Rest] = lists:reverse(Chars),
    List = lists:reverse(Rest),
    erlang:list_to_binary(List).

