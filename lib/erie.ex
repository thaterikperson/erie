defmodule Erie do
  def do_all() do
    dir = File.cwd!()
    file = Path.join(dir, "app.erie")

    with {:ok, forms} <- Erie.Parser.parse_file(file),
         {:ok, ast} <- Erie.Translator.to_eaf(forms) do
      {:ok, m, b} = :compile.forms(ast)

      :code.load_binary(m, 'nofile', b)
    else
      x -> IO.warn(inspect(x))
    end
  end
end
