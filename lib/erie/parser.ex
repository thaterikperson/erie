defmodule Erie.Parser do
  def parse_file(file_name) do
    with {:ok, contents} <- File.read(file_name) do
      parse(contents)
    end
  end

  def parse(contents) do
    with {:ok, tokens, _line} <- tokenize(contents) do
      :parser.parse(tokens)
    end
  end

  def tokenize(contents) do
    contents |> String.to_charlist() |> :scanner.string()
  end

  def to_ast(parsed) do
    case parsed do
      list when is_list(list) ->
        Enum.map(parsed, &to_ast/1)

      {_category, _line, val} ->
        to_ast(val)

      el ->
        el
    end
  end

  def ast_to_parsed(nil, line) do
    {:atom, line, nil}
  end

  def ast_to_parsed(list, line) when is_list(list) do
    Enum.map(list, fn x -> ast_to_parsed(x, line) end)
  end

  def ast_to_parsed(atom, line) when is_atom(atom) do
    {:atom, line, atom}
  end

  def ast_to_parsed(int, line) when is_integer(int) do
    {:integer, line, int}
  end

  def ast_to_parsed(ast, _line) do
    ast
  end
end
