defmodule Erie.Translator do
  alias Erie.{Macro, Translator}
  defstruct [:module, :functions, :macros, :macros_ast, :ast]

  def from_parsed(forms) do
    with {:ok, mod, mod_line, forms} <- extract_module(forms) do
      struct =
        %Translator{module: {mod, mod_line}, functions: [], macros: [], macros_ast: [], ast: []}
        |> translate(Enum.reverse(forms), [])
        |> prepend_headers()

      # macro_struct = to_macro_module_eaf(struct)
      Macro.compile_macros(struct)

      # %Translator{module: {mod, mod_line}, functions: [], macros: [], macros_ast: [], ast: []}
      struct =
        %{struct | ast: [], functions: []}
        |> translate(Enum.reverse(forms), [])
        |> prepend_headers()

      {:ok, struct}
    end
  end

  def to_eaf(forms) do
    with {:ok, struct} <- from_parsed(forms) do
      {:ok, struct.ast}
    end
  end

  def to_macro_module_eaf(%{module: {module, _}} = struct) do
    module = String.to_atom("MACRO." <> Atom.to_string(module))

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
      [{:atom, _, :sig}, {:atom, _line, _name} | _params] ->
        # ignoring type information for now
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

      [{:atom, _, :defmacro}, {:atom, line, name}, {:list, _, params} | body] ->
        body = translate_body(struct, body)
        params = params |> translate_params([]) |> Enum.reverse()
        arity = Enum.count(params)

        macros = [
          {:function, line, name, arity, [{:clause, line, params, [], body}]}
          | struct.macros_ast
        ]

        %{struct | macros: [{name, arity} | struct.macros], macros_ast: macros}
        |> translate(tail, ret)

      [{:atom, line, :def} | _] ->
        translate(struct, tail, [{:error, line} | ret])

      _ ->
        raise "derp #{inspect(form)}"
    end
  end

  def translate(struct, [], ret), do: %{struct | ast: ret}

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
      raise "execute the macro"
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

  def translate_cons([{_, line, _} = head | tail], _) do
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
end
