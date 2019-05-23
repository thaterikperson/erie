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
end
