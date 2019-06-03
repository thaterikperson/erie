Nonterminals list literal_list literal_tuple elems elem group.
Terminals '[' ']' '(' ')' '{' '}' integer float atom symbol string.
Rootsymbol group.

group -> list       : ['$1'].
group -> list group : ['$1'|'$2'].

list -> '(' ')'       : [].
list -> '(' elems ')' : '$2'.

literal_list -> '[' ']'       : {list, extract_line('$1'), []}.
literal_list -> '[' elems ']' : {list, extract_line('$1'), '$2'}.

literal_tuple -> '{' '}'       : {tuple, extract_line('$1'), []}.
literal_tuple -> '{' elems '}' : {tuple, extract_line('$1'), '$2'}.

elems -> elem       : ['$1'].
elems -> elem elems : ['$1'|'$2'].

elem -> atom          : '$1'.
elem -> float         : '$1'.
elem -> integer       : '$1'.
elem -> list          : '$1'.
elem -> symbol        : '$1'.
elem -> string        : '$1'.
elem -> literal_list  : '$1'.
elem -> literal_tuple : '$1'.

Erlang code.

extract_line({_, Line}) ->
    Line.
