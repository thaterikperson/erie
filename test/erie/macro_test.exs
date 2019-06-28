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

    test "infix" do
      code = """
      (defmodule Core)
      (defmacro infix [ast]
        ((lambda [list]
          [(Elixir.Enum.at list 1) (Elixir.Enum.at list 0) (Elixir.Enum.at list 2)])
          (Elixir.Enum.at ast 0)))

      (def one_plus_two []
        (infix (1 + 2)))
      """

      {:ok, forms} = Parser.parse(code)
      {:ok, ast} = Translator.to_eaf(forms)

      assert [
               {:attribute, 1, :module, :"Erie.Core"},
               {:attribute, 1, :export, [one_plus_two: 0]},
               {:function, 7, :one_plus_two, 0,
                [
                  {:clause, 7, [], [],
                   [
                     {:call, 8, {:atom, 8, :+}, [{:integer, 8, 1}, {:integer, 8, 2}]}
                   ]}
                ]}
             ] == ast
    end

    test "macro returns a list" do
      code = """
      (defmodule Core)
      (defmacro a_list [ast]
        ['cons 1 nil])

      (def map_it []
        (Elixir.List.first (a_list nil)))
      """

      {:ok, forms} = Parser.parse(code)
      {:ok, ast} = Translator.to_eaf(forms)

      assert [
               {:attribute, 1, :module, :"Erie.Core"},
               {:attribute, 1, :export, [map_it: 0]},
               {:function, 5, :map_it, 0,
                [
                  {:clause, 5, [], [],
                   [
                     {:call, 6, {:remote, 6, {:atom, 6, :"Elixir.List"}, {:atom, 6, :first}},
                      [
                        {:call, 6, {:atom, 6, :cons}, [{:integer, 6, 1}, {:atom, 6, nil}]}
                      ]}
                   ]}
                ]}
             ] == ast
    end
  end
end
