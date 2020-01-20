defmodule Erie.TypeExpander do
  def available_type_definition(name, available_types) do
    available_types
    |> Enum.find(fn
      {{:Union, n}, _, _} -> name == n
      _ -> false
    end)
    |> case do
      nil ->
        raise "Unable to find type definition for #{name}."

      other ->
        other
    end
  end

  def expand_definition({{:Union, _name}, params, options}, concrete_params) do
    Enum.map(options, fn option ->
      replace_type_parameters(option, params, concrete_params)
    end)
  end

  def collect_unexandable_options({:Symbol, symbol}) when is_atom(symbol), do: {:Symbol, symbol}
  def collect_unexandable_options(atom) when is_atom(atom), do: atom

  def collect_unexandable_options(list) when is_list(list) do
    Enum.map(list, &collect_unexandable_options/1)
  end

  def collect_unexandable_options({:TupleInvocation, options}) do
    {:TupleInvocation, Enum.map(options, fn option -> collect_unexandable_options(option) end)}
  end

  def collect_unexandable_options({{:UnionInvocation, _}, options}) do
    Enum.map(options, fn option -> collect_unexandable_options(option) end)
  end

  def expand_invocation({{:UnionInvocation, name}, options}, available_types) do
    new_options =
      name
      |> available_type_definition(available_types)
      |> expand_definition(options)
      |> Enum.map(fn option -> expand_invocation(option, available_types) end)
      |> Enum.reduce([], fn option, accum ->
        case collect_unexandable_options(option) do
          list when is_list(list) ->
            list ++ accum

          other ->
            [other | accum]
        end
      end)

    {{:UnionInvocation, name}, new_options}
  end

  def expand_invocation(type, _available_types), do: type

  def replace_in_list([], _match, _replacement), do: []

  def replace_in_list([head | tail], match, replacement) do
    new_head = if head == match, do: replacement, else: head
    [new_head | replace_in_list(tail, match, replacement)]
  end

  def do_replace(possible_replaceable_params, type_params, concrete_params) do
    if length(type_params) != length(concrete_params) do
      raise "Incorrect number of params"
    end

    type_params
    |> Enum.zip(concrete_params)
    |> Enum.reduce(possible_replaceable_params, fn {to_replace, concrete}, accum ->
      replace_in_list(accum, to_replace, concrete)
    end)
  end

  def replace_type_parameters(parameterized_type, type_params, concrete_params) do
    case parameterized_type do
      {{:UnionInvocation, name}, params} ->
        {{:UnionInvocation, name}, do_replace(params, type_params, concrete_params)}

      {:TupleInvocation, params} ->
        {:TupleInvocation, do_replace(params, type_params, concrete_params)}

      {:ListInvocation, param} ->
        [replaced] = do_replace([param], type_params, concrete_params)
        {:ListInvocation, replaced}

      {:Symbol, symbol} ->
        {:Symbol, symbol}

      other when is_atom(other) ->
        if Erie.TypeChecker.valid_type_param_name?(other) do
          [result] = do_replace([other], type_params, concrete_params)
          result
        else
          other
        end
    end
  end
end
