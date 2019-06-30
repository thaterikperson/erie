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

  def compile(code, mod_pair \\ nil) do
    translator_func =
      case mod_pair do
        nil -> fn forms -> %{ast: elem(Erie.Translator.to_eaf(forms), 1)} end
        {mod, mod_line} -> fn forms -> Erie.Translator.from_parsed(forms, {mod, mod_line}) end
      end

    with {:ok, forms} <- Erie.Parser.parse(code),
         {:ok, %{ast: ast}} <- {:ok, translator_func.(forms)},
         {:ok, m, b} <- :compile.forms(ast) do
      :code.load_binary(m, 'nofile', b)
    end
  end
end
