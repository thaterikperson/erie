defmodule Erie.TypeChecker do
  def check(translator) do
    return_types = last_expression_types(translator.ast, translator.signatures)

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

  def matching(possible_return_types, name, arity) do
    Enum.find(possible_return_types, fn {r_name, r_arity, _} ->
      r_name == name && r_arity == arity
    end)
  end

  def last_expression_types(ast, signatures) do
    ast
    |> Enum.filter(fn row -> elem(row, 0) == :function end)
    |> Enum.map(fn {:function, _line, name, arity, _clauses} = t ->
      {name, arity, last_expression_type(t, signatures)}
    end)
  end

  def last_expression_type({:function, _, _, _, clauses}, signatures) do
    clauses |> List.last() |> last_expression_type(signatures)
  end

  def last_expression_type({:clause, _, _params, _guards, expressions}, signatures) do
    expressions |> List.last() |> expression_type(signatures)
  end

  def expression_type({:integer, _, _}, _), do: :Integer
  def expression_type({:bin, _, _}, _), do: :String

  def expression_type({:call, _, {:atom, _, name}, params}, signatures) do
    signatures
    |> Enum.find(fn {s_name, {s_params, _}} ->
      name == s_name && Enum.count(params) == Enum.count(s_params)
    end)
    |> case do
      nil -> raise "Can't find local function call #{name}"
      {_, {_, s_return_type}} -> s_return_type
    end
  end
end
