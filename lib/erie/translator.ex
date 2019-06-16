defmodule Erie.Translator do
  alias Erie.Translator
  defstruct [:module, :functions, :ast]

  def to_eaf(forms) do
    with {:ok, mod, mod_line, forms} <- extract_module(forms) do
      struct =
        %Translator{module: {mod, mod_line}, functions: [], ast: []}
        |> translate(Enum.reverse(forms), [])
        |> prepend_headers()

      {:ok, struct.ast}
    end
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
        body = translate_body(body)
        params = params |> translate_params([]) |> Enum.reverse()
        arity = Enum.count(params)

        %{struct | functions: [{name, arity} | struct.functions]}
        |> translate(tail, [
          {:function, line, name, arity, [{:clause, line, params, [], body}]}
          | ret
        ])

      [{:atom, line, :def} | _] ->
        translate(struct, tail, [{:error, line} | ret])

      _ ->
        raise "derp #{inspect(form)}"
    end
  end

  def translate(struct, [], ret), do: %{struct | ast: ret}

  def translate_body(list) do
    list |> translate_body([]) |> Enum.reverse()
  end

  def translate_body([[[{_, line, _} = head | tail] | params] | rest], accum) do
    [body] = translate_body([[head | tail]])
    params = translate_body(params)
    ast = {:call, line, body, params}

    translate_body(rest, [ast | accum])
  end

  def translate_body([[{:atom, line, :case}, matcher | matches] | rest], accum) do
    [matcher] = translate_body([matcher], [])
    clauses = matches |> translate_case([]) |> Enum.reverse()
    ast = {:case, line, matcher, clauses}

    translate_body(rest, [ast | accum])
  end

  def translate_body(
        [[{:atom, line, :lambda}, {:list, clause_line, params} | lambda_body] | rest],
        accum
      ) do
    body = translate_body(lambda_body)
    params = params |> translate_params([]) |> Enum.reverse()

    ast =
      {:fun, line,
       {:clauses,
        [
          {:clause, clause_line, params, [], body}
        ]}}

    translate_body(rest, [ast | accum])
  end

  def translate_body([[{:atom, line, val} | func_args] | rest], accum) do
    args = translate_body(func_args)
    ast = {:call, line, {:atom, line, val}, args}
    translate_body(rest, [ast | accum])
  end

  def translate_body([[{:symbol, line, val} | func_args] | rest], accum) do
    args = translate_body(func_args)
    [func | mod_parts] = val |> Atom.to_string() |> String.split(".") |> Enum.reverse()
    mod = mod_parts |> Enum.reverse() |> Enum.join(".") |> String.to_atom()
    func = String.to_atom(func)

    ast = {:call, line, {:remote, line, {:atom, line, mod}, {:atom, line, func}}, args}
    translate_body(rest, [ast | accum])
  end

  def translate_body([{:atom, line, val} | rest], accum) do
    translate_body(rest, [{:var, line, val} | accum])
  end

  def translate_body([{:integer, line, val} | rest], accum) do
    translate_body(rest, [{:integer, line, val} | accum])
  end

  def translate_body([{:list, line, val} | rest], accum) do
    tuple = val |> translate_body() |> translate_cons(line)

    translate_body(rest, [tuple | accum])
  end

  def translate_body([{:string, line, val} | rest], accum) do
    tuple =
      {:bin, line,
       [{:bin_element, line, {:string, line, String.to_charlist(val)}, :default, :default}]}

    translate_body(rest, [tuple | accum])
  end

  def translate_body([{:tuple, line, val} | rest], accum) do
    list = translate_body(val)
    tuple = {:tuple, line, list}
    translate_body(rest, [tuple | accum])
  end

  def translate_body([], accum) do
    accum
  end

  def translate_case([{:list, line, [match | body]} | rest], accum) do
    body = translate_body(body)
    ast = {:clause, line, [translate_case_clause(match)], [], body}
    translate_case(rest, [ast | accum])
  end

  def translate_case([], accum) do
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
