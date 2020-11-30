defmodule Erie.MacroTest do
  use ExUnit.Case
  alias Erie.{Macro, Parser, Translator}

  describe "expand1" do
    test "no macro" do
      code = """
      (defmodule Core)
      (doc literals [] Any)
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

      (doc one_plus_two [] Integer)
      (def one_plus_two []
        (infix (1 + 2)))
      """

      {:ok, forms} = Parser.parse(code)
      {:ok, ast} = Translator.to_eaf(forms)

      assert [
               {:attribute, 1, :module, :"Erie.Core"},
               {:attribute, 1, :export, [one_plus_two: 0]},
               {:function, 8, :one_plus_two, 0,
                [
                  {:clause, 8, [], [],
                   [
                     {:call, 9, {:atom, 9, :+}, [{:integer, 9, 1}, {:integer, 9, 2}]}
                   ]}
                ]}
             ] == ast
    end

    test "macro returns a list" do
      code = """
      (defmodule Core)
      (defmacro a_list [ast]
        ['cons 1 nil])

      (doc map_it [] (Maybe Integer))
      (def map_it []
        (Elixir.List.first (a_list nil)))
      """

      {:ok, forms} = Parser.parse(code)
      {:ok, ast} = Translator.to_eaf(forms)

      assert [
               {:attribute, 1, :module, :"Erie.Core"},
               {:attribute, 1, :export, [map_it: 0]},
               {:function, 6, :map_it, 0,
                [
                  {:clause, 6, [], [],
                   [
                     {:call, 7, {:remote, 7, {:atom, 7, :"Elixir.List"}, {:atom, 7, :first}},
                      [
                        {:call, 7, {:atom, 7, :cons}, [{:integer, 7, 1}, {:atom, 7, nil}]}
                      ]}
                   ]}
                ]}
             ] == ast
    end
  end
end
