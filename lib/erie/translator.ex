defmodule Erie.Translator do
  alias Erie.{Macro, Translator}

  defstruct [
    :do_eval?,
    :module,
    :functions,
    :macros,
    :macros_ast,
    :ast,
    :ast_to_eval,
    :types,
    :signatures
  ]

  def to_eaf(forms) do
    with {:ok, mod, mod_line, forms} <- extract_module(forms) do
      struct = from_parsed(forms, {mod, mod_line}, false)
      {:ok, struct.ast}
    end
  end

  def from_parsed(forms, {mod, mod_line}, do_eval?) do
    forms = Enum.reverse(forms)

    struct =
      %Translator{
        do_eval?: do_eval?,
        module: {mod, mod_line},
        functions: [],
        macros: [],
        macros_ast: [],
        ast: [],
        ast_to_eval: nil,
        types: [],
        signatures: []
      }
      |> translate_macros(forms, [])

    Macro.compile_macros(struct)

    struct
    |> translate(forms, [])
    |> prepend_headers()
  end

  def macro_module_name(%{module: {module, _}}) do
    String.to_atom("MACRO." <> Atom.to_string(module))
  end

  def to_macro_module_eaf(struct) do
    module = macro_module_name(struct)

    %Translator{module: {module, 1}, ast: struct.macros_ast, functions: struct.macros}
    |> prepend_headers()
  end

  def prepend_headers(struct) do
    %{module: {mod, mod_line}, ast: ast} = struct
    ast = [{:attribute, mod_line, :module, mod}, {:attribute, 1, :export, struct.functions} | ast]
    %{struct | ast: ast}
  end

  def extract_module([[{:atom, _, :defmodule}, {:symbol, line, mod}] | rest]) do
    mod = ("Erie." <> Atom.to_string(mod)) |> String.to_atom()
    {:ok, mod, line, rest}
  end

  def extract_module(_) do
    {:error, :invalid_module_declaration}
  end

  def translate(struct, [form | tail], ret) do
    case form do
      [{:atom, _, :doc}, {:atom, _line, name}, {:list, _, _} = params, return_type] ->
        param_types = translate_type(params)
        return_type = translate_type(return_type)
        signatures = [{name, {param_types, return_type}} | struct.signatures]
        struct = %{struct | signatures: signatures}
        translate(struct, tail, ret)

      [{:atom, _, :def}, {:atom, line, name}, {:list, _, params} | body] ->
        body = translate_body(struct, body)
        params = params |> translate_params([]) |> Enum.reverse()
        arity = Enum.count(params)

        %{struct | functions: [{name, arity} | struct.functions]}
        |> translate(tail, [
          {:function, line, name, arity, [{:clause, line, params, [], body}]}
          | ret
        ])

      [{:atom, _, :defmacro} | _] ->
        translate(struct, tail, ret)

      [{:atom, _, :deftype}, {:symbol, _line, name}, {:list, _, params}, body] ->
        type = translate_deftype(name, params, body)

        %{struct | types: [type | struct.types]}
        |> translate(tail, ret)

      [{:atom, line, :def} | _] ->
        translate(struct, tail, [{:error, line} | ret])

      other ->
        if struct.do_eval? do
          [parsed] = translate_body(%{macros: []}, [other])
          %{struct | ast_to_eval: parsed}
        else
          raise "unknown form #{inspect(form)}"
        end
    end
  end

  def translate(struct, [], ret), do: %{struct | ast: ret}

  def translate_macros(struct, [form | tail], ret) do
    case form do
      [{:atom, _, :defmacro}, {:atom, line, name}, {:list, _, params} | body] ->
        body = translate_body(struct, body)
        params = params |> translate_params([]) |> Enum.reverse()
        arity = Enum.count(params)

        macros = {:function, line, name, arity, [{:clause, line, params, [], body}]}

        %{struct | macros: [{name, arity} | struct.macros]}
        |> translate_macros(tail, [macros | ret])

      _ ->
        translate_macros(struct, tail, ret)
    end
  end

  def translate_macros(struct, [], ret), do: %{struct | macros_ast: ret}

  def translate_body(struct, list) do
    struct |> translate_body(list, []) |> Enum.reverse()
  end

  def translate_body(struct, [[[{_, line, _} = head | tail] | params] | rest], accum) do
    [body] = translate_body(struct, [[head | tail]])
    params = translate_body(struct, params)
    ast = {:call, line, body, params}

    translate_body(struct, rest, [ast | accum])
  end

  def translate_body(struct, [[{:atom, line, :case}, matcher | matches] | rest], accum) do
    [matcher] = translate_body(struct, [matcher], [])
    clauses = struct |> translate_case(matches, []) |> Enum.reverse()
    ast = {:case, line, matcher, clauses}

    translate_body(struct, rest, [ast | accum])
  end

  def translate_body(
        struct,
        [[{:atom, line, :lambda}, {:list, clause_line, params} | lambda_body] | rest],
        accum
      ) do
    body = translate_body(struct, lambda_body)
    params = params |> translate_params([]) |> Enum.reverse()

    ast =
      {:fun, line,
       {:clauses,
        [
          {:clause, clause_line, params, [], body}
        ]}}

    translate_body(struct, rest, [ast | accum])
  end

  def translate_body(struct, [[{:atom, line, val} | func_args] | rest], accum) do
    macro_names = Enum.map(struct.macros, fn {name, _arity} -> name end)

    if Enum.member?(macro_names, val) do
      args_ast = Erie.Parser.to_ast(func_args)
      macro_module = macro_module_name(struct)

      [new_ast] =
        macro_module
        |> apply(val, [args_ast])
        |> Erie.Parser.ast_to_parsed(line)
        |> (fn parsed -> translate_body(struct, [parsed]) end).()

      translate_body(struct, rest, [new_ast | accum])
    else
      args = translate_body(struct, func_args)
      ast = {:call, line, {:atom, line, val}, args}
      translate_body(struct, rest, [ast | accum])
    end
  end

  def translate_body(struct, [[{:symbol, line, val} | func_args] | rest], accum) do
    args = translate_body(struct, func_args)
    [func | mod_parts] = val |> Atom.to_string() |> String.split(".") |> Enum.reverse()
    mod = mod_parts |> Enum.reverse() |> Enum.join(".") |> String.to_atom()
    func = String.to_atom(func)

    ast = {:call, line, {:remote, line, {:atom, line, mod}, {:atom, line, func}}, args}
    translate_body(struct, rest, [ast | accum])
  end

  def translate_body(struct, [{:atom, line, nil} | rest], accum) do
    translate_body(struct, rest, [{:atom, line, nil} | accum])
  end

  def translate_body(struct, [{:atom, line, val} | rest], accum) do
    translate_body(struct, rest, [{:var, line, val} | accum])
  end

  def translate_body(struct, [{:integer, line, val} | rest], accum) do
    translate_body(struct, rest, [{:integer, line, val} | accum])
  end

  def translate_body(struct, [{:list, line, val} | rest], accum) do
    tuple = struct |> translate_body(val) |> translate_cons(line)

    translate_body(struct, rest, [tuple | accum])
  end

  def translate_body(struct, [{:string, line, val} | rest], accum) do
    tuple =
      {:bin, line,
       [{:bin_element, line, {:string, line, String.to_charlist(val)}, :default, :default}]}

    translate_body(struct, rest, [tuple | accum])
  end

  def translate_body(struct, [{:symbol, line, val} | rest], accum) do
    translate_body(struct, rest, [{:atom, line, val} | accum])
  end

  def translate_body(struct, [{:tuple, line, val} | rest], accum) do
    list = translate_body(struct, val)
    tuple = {:tuple, line, list}
    translate_body(struct, rest, [tuple | accum])
  end

  def translate_body(_struct, [], accum) do
    accum
  end

  def translate_case(struct, [{:list, line, [match | body]} | rest], accum) do
    body = translate_body(struct, body)
    ast = {:clause, line, [translate_case_clause(match)], [], body}
    translate_case(struct, rest, [ast | accum])
  end

  def translate_case(_struct, [], accum) do
    accum
  end

  def translate_case_clause({:symbol, line, symbol}) do
    {:atom, line, symbol}
  end

  def translate_case_clause({:atom, line, :_}) do
    {:var, line, :_}
  end

  def translate_case_clause({:atom, line, atom}) do
    {:var, line, atom}
  end

  def translate_cons([head | tail], _) do
    line = elem(head, 1)
    {:cons, line, head, translate_cons(tail, line)}
  end

  def translate_cons([], line) do
    {nil, line}
  end

  def translate_params([{:atom, line, name} | rest], accum) do
    translate_params(rest, [{:var, line, name} | accum])
  end

  def translate_params([], accum) do
    accum
  end

  def translate_type({:tuple, _, types}) do
    translated = Enum.map(types, &translate_type/1)
    {:TupleInvocation, translated}
  end

  def translate_type({:list, _, types}) do
    Enum.map(types, &translate_type/1)
  end

  def translate_type([first | params]) do
    params = Enum.map(params, &translate_type/1)

    case {translate_type(first), params} do
      {:Tuple, _} ->
        {:TupleInvocation, params}

      {:List, [param]} ->
        {:ListInvocation, param}

      {{{:UnionInvocation, name}, []}, params} ->
        {{:UnionInvocation, name}, params}

      {other, _} ->
        {{:UnionInvocation, other}, params}
    end
  end

  def translate_type(list) when is_list(list) do
    args = Enum.join(list, " ")
    raise "Attempting to call (#{args}) as a function but it isn't one."
  end

  def translate_type({:symbol, _, symbol}) do
    name = Atom.to_string(symbol)

    # Doing this for now because the parser treats words with
    # capital letters as symbols. That may change in the future.
    if String.upcase(String.first(name)) == String.first(name) do
      if symbol in Erie.Builtin.type_names() do
        symbol
      else
        {{:UnionInvocation, symbol}, []}
      end
    else
      {:Symbol, symbol}
    end
  end

  def translate_type({:atom, _, atom}) do
    atom
  end

  def translate_deftype(name, params, [{:atom, _, :union}, {:list, _, union_options}]) do
    param_types = Enum.map(params, &translate_type/1)
    option_types = Enum.map(union_options, &translate_type/1)
    {{:Union, name}, param_types, option_types}
  end

  def translate_deftype(_name, _params, _body) do
    raise "Only union types are supported with deftype right now."
  end
end
