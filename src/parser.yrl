Nonterminals list elems elem group.
Terminals '(' ')' integer float atom symbol.
Rootsymbol group.

group -> list : ['$1'].
group -> list group : ['$1'|'$2'].

list -> '(' ')'       : [].
list -> '(' elems ')' : '$2'.

elems -> elem           : ['$1'].
elems -> elem elems : ['$1'|'$2'].

elem -> atom : '$1'.
elem -> float : '$1'.
elem -> integer  : '$1'.
elem -> list : '$1'.
elem -> symbol : '$1'.

Erlang code.
