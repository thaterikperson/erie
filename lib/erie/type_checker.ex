defmodule Erie.TypeChecker do
  def check(translator) do
    # IO.inspect(translator)
    function_asts = Enum.filter(translator.ast, fn line -> elem(line, 0) == :function end)

    typed_signatures = match_functions_to_signatures(function_asts, translator.signatures)
    # |> IO.inspect(label: "type signatures")

    return_types = match_last_expression_types(function_asts, typed_signatures)
    # |> IO.inspect(label: "return types")

    translator.signatures
    |> Enum.each(fn {name, {param_types, return_type}} ->
      case matching(return_types, name, Enum.count(param_types)) do
        nil ->
          raise "Missing a (def) for #{name}/#{Enum.count(param_types)}"

        {_, _, r_type} ->
          if r_type == return_type do
            :ok
          else
            raise "#{name} doc says #{return_type} but I think it's #{r_type}"
          end
      end
    end)
  end

  def match_functions_to_signatures(ast, signatures) do
    ast
    |> Enum.map(fn {:function, _, name, arity, [clause]} ->
      {:clause, _, vars, _, _body} = clause

      types =
        signatures
        |> Enum.find(fn {s_name, {s_params, _}} ->
          name == s_name && arity == Enum.count(s_params)
        end)
        |> case do
          {_, {param_types, return_type}} ->
            names_with_types =
              vars
              |> Enum.map(fn {:var, _, var_name} -> var_name end)
              |> Enum.zip(param_types)

            {names_with_types, return_type}

          nil ->
            raise "Could not find a signature for the #{name}/#{arity} function"
        end

      {name, types}
    end)
  end

  def matching(possible_return_types, name, arity) do
    Enum.find(possible_return_types, fn {r_name, r_arity, _} ->
      r_name == name && r_arity == arity
    end)
  end

  def match_last_expression_types(ast, signatures) do
    ast
    |> Enum.map(fn {:function, _line, name, arity, clauses} ->
      {:clause, _, _, _, expressions} = List.last(clauses)

      {_, {param_types, _return_type}} =
        Enum.find(signatures, fn {n, {p, _r}} ->
          n == name && Enum.count(p) == arity
        end)

      type = expressions |> List.last() |> expression_type(param_types, signatures)
      {name, arity, type}
    end)
  end

  def expression_type({:integer, _, _}, _, _), do: :Integer
  def expression_type({:bin, _, _}, _, _), do: :String

  def expression_type({:call, _, {:atom, _, name}, params}, bindings, signatures) do
    signatures
    |> Enum.find(fn {s_name, {s_params, _}} ->
      name == s_name && Enum.count(params) == Enum.count(s_params)
    end)
    |> case do
      nil ->
        raise "Can't find local function call #{name}"

      {_, {s_params, s_return_type}} ->
        zip_params(params, s_params, bindings, signatures)

        s_return_type
    end
  end

  def expression_type({:var, _, name}, bindings, _signatures) do
    bindings
    |> Enum.find(fn {n, _} -> n == name end)
    |> case do
      nil -> raise "Returning a binding `#{name}` that isn't a function parameter"
      {_, type} -> type
    end
  end

  # treat `{nil, _}` separately in a `cons`.
  # `nil` here indicates in the end of the cons
  # and should not be treated as a `(Maybe x)`
  def expression_type({:cons, _, val, {nil, _}}, bindings, signatures) do
    [expression_type(val, bindings, signatures)]
  end

  def expression_type({:cons, _, val, remainder}, bindings, signatures) do
    first_type = expression_type(val, bindings, signatures)
    [remainder_type] = expression_type(remainder, bindings, signatures)

    if first_type == remainder_type do
      :ok
    else
      raise "Mismatched types in list. Expecting #{first_type} but found #{remainder_type}"
    end

    [first_type]
  end

  @doc """
  `callers` is the ast of each parameter. E.g. `{:var, 3, :x}`
  `defined` is what is expected from the function definition. E.g. {:y, :String}
  The names of the parameters from either don't need to line up,
  but the length of each list needs to be equal.
  """
  def zip_params(callers, defined, bindings, signatures) do
    # IO.inspect(callers, label: "callers")
    # IO.inspect(defined, label: "defined")
    # IO.inspect(bindings, label: "bindings")
    # IO.inspect(signatures, label: "signatures")

    if Enum.count(callers) != Enum.count(defined) do
      raise "Incorrect number of parameters in function call"
    end

    caller_types =
      Enum.map(callers, fn caller -> expression_type(caller, bindings, signatures) end)

    # |> IO.inspect(label: "caller types")

    defined_types = Enum.map(defined, fn {_, type} -> type end)

    Enum.zip(caller_types, defined_types)
    |> Enum.each(fn {caller_type, defined_type} ->
      if caller_type == defined_type do
        :ok
      else
        raise "Have type of #{caller_type} but expecting type of #{defined_type}"
      end
    end)
  end
end
