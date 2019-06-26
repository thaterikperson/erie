defmodule Erie.MacroTest do
  use ExUnit.Case
  alias Erie.{Macro, Parser, Translator}

  describe "expand1" do
    test "no macro" do
      code = """
      (defmodule Core)
      (sig literals Any)
      (def literals []
        {"abc" [] [1 2 3]})
      """

      {:ok, forms} = Parser.parse(code)

      assert forms == Macro.expand(forms)
    end

    test "comment" do
      code = """
      (defmodule Core)
      (defmacro comment [ast]
        nil)

      (def loop []
        (comment 1))
      """

      {:ok, forms} = Parser.parse(code)
      {:ok, ast} = Translator.to_eaf(forms)

      assert [
               {:attribute, 1, :module, :"Erie.Core"},
               {:attribute, 1, :export, [loop: 0]},
               {:function, 5, :loop, 0,
                [
                  {:clause, 5, [], [], [{:atom, 6, nil}]}
                ]}
             ] == ast
    end
  end
end
