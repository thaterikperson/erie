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

  def step_into(translator, [head | tail]) when is_list(head) do
    [step_into(translator, head) | step_into(translator, tail)]
  end

  def step_into(translator, [possible_macro_name | args]) do
    macro_names = Enum.map(translator.functions, fn {name, _arity} -> name end)

    if Enum.member?(macro_names, possible_macro_name) do
      IO.puts("Found #{possible_macro_name}")
      # invoke the macro with args and return that
      [possible_macro_name | args]
    else
      [possible_macro_name | args]
    end
  end

  def step_into(_translator, []) do
    []
  end
end
