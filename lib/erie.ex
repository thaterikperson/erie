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

  def compile_and_eval(code, {mod, mod_line}) do
    with {:ok, forms} <- Erie.Parser.parse(code),
         translator <- Erie.Translator.from_parsed(forms, {mod, mod_line}, true),
         {:ok, m, b} <- :compile.forms(translator.ast) do
      :code.load_binary(m, 'nofile', b)

      case translator.ast_to_eval do
        nil -> :ok
        to_eval -> :erl_eval.expr(to_eval, [])
      end
    end
  end
end
