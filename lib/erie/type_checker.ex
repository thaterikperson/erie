defmodule Erie.TypeChecker do
  def check(translator) do
    # IO.inspect(translator)
    all_signature_types_are_valid!(
      translator.signatures,
      Erie.Builtin.types() ++ translator.types
    )

    function_asts = Enum.filter(translator.ast, fn line -> elem(line, 0) == :function end)

    typed_signatures = match_functions_to_signatures(function_asts, translator.signatures)
    # |> IO.inspect(label: "type signatures")

    return_types = match_last_expression_types(function_asts, typed_signatures)
    # |> IO.inspect(label: "return types")

    translator.signatures
    |> Enum.each(fn {name, {param_types, sig_return_type}} ->
      case matching(return_types, name, Enum.count(param_types)) do
        nil ->
          raise "Missing a (def) for #{name}/#{Enum.count(param_types)}"

        {_, _, calculated_return_type} ->
          cond do
            calculated_return_type == sig_return_type ->
              :ok

            # nil is the equivalent of an empty list.
            # if the type is calculated as nil, that
            # works if the defined type is of any list.
            list_type?(sig_return_type) && is_nil(calculated_return_type) ->
              :ok

            type_conforms_to_possible_type?(
              calculated_return_type,
              sig_return_type,
              Erie.Builtin.types() ++ translator.types
            ) ->
              :ok

            :else ->
              raise "#{name} doc says #{inspect(sig_return_type)} but I think it's #{
                      inspect(calculated_return_type)
                    }"
          end
      end
    end)
  end

  def list_type?({:List, [_]}), do: true
  def list_type?(_), do: false

  def all_signature_types_are_valid!(signatures, types) do
    signatures
    |> Enum.flat_map(fn {_name, {param_types, return_type}} ->
      [return_type | param_types]
    end)
    |> Enum.filter(fn type -> not signature_type_exists?(type, types) end)
    |> Enum.each(fn type ->
      raise "Unable to find definition for type #{inspect(type)}."
    end)
  end

  def signature_type_exists?(signature_type, available_types) do
    available_types
    |> Enum.any?(fn available_type ->
      case {signature_type, available_type} do
        {sig_atom, avail_atom} when is_atom(sig_atom) and is_atom(avail_atom) ->
          sig_atom == avail_atom

        {{:ListInvocation, sig_inner}, {:List, avail_inner}} ->
          valid_type_name?(sig_inner) && valid_type_param_name?(avail_inner)

        # Tuple must have at least two parameters
        {{:TupleInvocation, sig_list}, {:Tuple, avail_list}}
        when length(sig_list) > 1 and length(sig_list) == length(avail_list) ->
          Enum.all?(sig_list, &valid_type_name?/1) &&
            Enum.all?(avail_list, &valid_type_param_name?/1)

        {{{:UnionInvocation, sig_name}, sig_params}, {{:Union, avail_name}, avail_params, _}} ->
          sig_name == avail_name && Enum.count(sig_params) == Enum.count(avail_params)

        _else ->
          false
      end
    end)
  end

  def type_conforms_to_possible_type?(calculated_type, type_to_conform_to, available_types) do
    # IO.inspect(calculated_type, label: "calculated_type")
    # IO.inspect(type_to_conform_to, label: "type_to_conform_to")

    expanded_type = Erie.TypeExpander.expand_invocation(type_to_conform_to, available_types)

    case {calculated_type, expanded_type} do
      {l_atom, r_atom} when is_atom(l_atom) and is_atom(r_atom) ->
        l_atom == r_atom

      {_, {{:UnionInvocation, _}, options}} ->
        Enum.any?(options, fn o ->
          type_conforms_to_possible_type?(calculated_type, o, available_types)
        end)

      {{:Symbol, symbol1}, {:Symbol, symbol2}} ->
        symbol1 == symbol2

      {{:List, l_param}, {:ListInvocation, r_param}} ->
        l_param == r_param

      {nil, {:ListInvocation, _param}} ->
        true

      {{:Tuple, l_params}, {:TupleInvocation, r_params}} ->
        l_params
        |> Enum.zip(r_params)
        |> Enum.all?(fn {l, r} -> l == r end)

      _else ->
        false
    end
  end

  def valid_type_name?(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> first_letter_upcase?()
  end

  def valid_type_name?(_), do: false
  def valid_type_param_name?(atom), do: not valid_type_name?(atom)

  def first_letter_upcase?(name) do
    String.upcase(String.first(name)) == String.first(name)
  end

  def type_exists?() do
    # TODO
    # (deftype D [] (union A B))
    # How do we know A and/or B exist?
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

  def expression_type({nil, _}, _, _), do: nil
  def expression_type({:atom, _, atom}, _, _), do: {:Symbol, atom}
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
    {:List, expression_type(val, bindings, signatures)}
  end

  def expression_type({:cons, _, val, remainder}, bindings, signatures) do
    first_type = expression_type(val, bindings, signatures)
    {:List, remainder_type} = expression_type(remainder, bindings, signatures)

    if first_type == remainder_type do
      :ok
    else
      raise "Mismatched types in list. Expecting #{first_type} but found #{remainder_type}."
    end

    {:List, first_type}
  end

  def expression_type({:tuple, _, types}, bindings, signatures) do
    types = Enum.map(types, fn t -> expression_type(t, bindings, signatures) end)
    {:Tuple, types}
  end

  @doc """
  `callers` is the ast of each parameter. E.g. `{:var, 3, :x}`
  `defined` is what is expected from the function definition. E.g. {:y, :String}
  The names of the parameters from either don't need to line up,
  but the length of each list needs to be equal.
  """
  def zip_params(callers, defined, bindings, signatures) do
    if Enum.count(callers) != Enum.count(defined) do
      raise "Incorrect number of parameters in function call"
    end

    caller_types =
      Enum.map(callers, fn caller -> expression_type(caller, bindings, signatures) end)

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
