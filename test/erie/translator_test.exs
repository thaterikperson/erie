defmodule TranslatorTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator}
  doctest Erie.Parser

  test "0 arity" do
    code = ~S"""
    (defmodule Derie)
    (def name [] Integer (+ 1 2))
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Derie"},
              {:attribute, 1, :export, [name: 0]},
              {:function, 2, :name, 0,
               [
                 {:clause, 2, [], [], [{:op, 2, :+, {:integer, 2, 1}, {:integer, 2, 2}}]}
               ]}
            ]} = Translator.to_ast(forms)
  end

  test "1 arity" do
    code = ~S"""
    (defmodule Derie)
    (def name ['x Integer] Integer x)
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Derie"},
              {:attribute, 1, :export, [name: 1]},
              {:function, 2, :name, 1,
               [
                 {:clause, 2, [{:var, 2, :x}], [], [{:var, 2, :x}]}
               ]}
            ]} = Translator.to_ast(forms)
  end
end
