defmodule Erie.Translator do
  alias Erie.Translator
  defstruct [:module, :functions, :ast]

  def to_ast(forms) do
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
      [{:atom, _, :def}, {:atom, line, name}, params, {:symbol, _l2, _return_type} | body] ->
        body = translate_body(body)
        params = translate_params(params)
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

  def translate_body([[{:atom, line, :+}, p1, p2] | rest], accum) do
    translate_body(rest, [{:op, line, :+, p1, p2} | accum])
  end

  def translate_body([[{:atom, line, val} | func_args] | rest], accum) do
    args = translate_body(func_args, [])
    ast = {:call, line, {:atom, line, val}, args}
    translate_body(rest, [ast | accum])
  end

  def translate_body([[{:symbol, line, val} | func_args] | rest], accum) do
    args = translate_body(func_args, []) |> Enum.reverse()
    [func | mod_parts] = val |> Atom.to_string() |> String.split(".") |> Enum.reverse()
    mod = mod_parts |> Enum.reverse() |> Enum.join(".") |> String.to_atom()
    func = String.to_atom(func)

    ast = {:call, line, {:remote, line, {:atom, 3, mod}, {:atom, 3, func}}, args}
    translate_body(rest, [ast | accum])
  end

  def translate_body([{:integer, line, val} | rest], accum) do
    translate_body(rest, [{:integer, line, val} | accum])
  end

  def translate_body([{:atom, line, val} | rest], accum) do
    translate_body(rest, [{:var, line, val} | accum])
  end

  def translate_body([{:string, line, val} | rest], accum) do
    tuple =
      {:bin, line,
       [{:bin_element, line, {:string, line, String.to_charlist(val)}, :default, :default}]}

    translate_body(rest, [tuple | accum])
  end

  def translate_body([], accum) do
    accum
  end

  def translate_params(list) do
    list |> translate_params([]) |> Enum.reverse()
  end

  def translate_params([{:symbol, line, name}, {:symbol, _, _type} | rest], accum) do
    translate_params(rest, [{:var, line, name} | accum])
  end

  def translate_params([], accum) do
    accum
  end
end
