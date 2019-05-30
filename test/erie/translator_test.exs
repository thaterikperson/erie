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
            ]} == Translator.to_ast(forms)
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
            ]} == Translator.to_ast(forms)
  end

  test "local function call" do
    code = ~S"""
    (defmodule Core)
    (def identity ['x Integer] Integer x)
    (def again [] Integer
      (identity 3))
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Core"},
              {:attribute, 1, :export, [identity: 1, again: 0]},
              {:function, 2, :identity, 1,
               [
                 {:clause, 2, [{:var, 2, :x}], [], [{:var, 2, :x}]}
               ]},
              {:function, 3, :again, 0,
               [
                 {:clause, 3, [], [],
                  [
                    {:call, 4, {:atom, 4, :identity}, [{:integer, 4, 3}]}
                  ]}
               ]}
            ]} == Translator.to_ast(forms)
  end

  test "Elixir function call" do
    code = ~S"""
    (defmodule Core)
    (def split-by-comma ['str String] String
      (Elixir.String.split str ","))
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Core"},
              {:attribute, 1, :export, [{:"split-by-comma", 1}]},
              {:function, 2, :"split-by-comma", 1,
               [
                 {:clause, 2, [{:var, 2, :str}], [],
                  [
                    {:call, 3, {:remote, 3, {:atom, 3, :"Elixir.String"}, {:atom, 3, :split}},
                     [
                       {:var, 3, :str},
                       {:bin, 3, [{:bin_element, 3, {:string, 3, ","}, :default, :default}]}
                     ]}
                  ]}
               ]}
            ]} == Translator.to_ast(forms)
  end
end
