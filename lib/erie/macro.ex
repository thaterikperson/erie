defmodule Erie.Macro do
  alias Erie.Translator

  def expand(ast) do
    ast
  end

  def compile_macros(translator) do
    macro_translator = Translator.to_macro_module_eaf(translator)
    %{ast: ast} = macro_translator
    {:ok, m, b} = :compile.forms(ast)

    :code.load_binary(m, 'nofile', b)
  end
end
