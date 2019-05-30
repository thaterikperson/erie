defmodule ParserTest do
  use ExUnit.Case
  alias Erie.Parser
  doctest Erie.Parser

  describe "tokenizer" do
    test "defmodule" do
      code = ~S"""
      (defmodule Derie)
      """

      assert {:ok, [{:"(", 1}, {:atom, 1, :defmodule}, {:symbol, 1, :Derie}, {:")", 1}], _} =
               Parser.tokenize(code)
    end

    test "1 arity function" do
      code = ~S"""
      (def name ['x Integer] Integer x)
      """

      assert {:ok,
              [
                {:"(", 1},
                {:atom, 1, :def},
                {:atom, 1, :name},
                {:"(", 1},
                {:symbol, 1, :x},
                {:symbol, 1, :Integer},
                {:")", 1},
                {:symbol, 1, :Integer},
                {:atom, 1, :x},
                {:")", 1}
              ], _} = Parser.tokenize(code)
    end

    test "string literal" do
      code = ~S"""
      (def name [] String "abc")
      """

      assert {:ok,
              [
                {:"(", 1},
                {:atom, 1, :def},
                {:atom, 1, :name},
                {:"(", 1},
                {:")", 1},
                {:symbol, 1, :String},
                {:string, 1, "abc"},
                {:")", 1}
              ], 2} = Parser.tokenize(code)
    end
  end

  describe "parser" do
    test "defmodule" do
      code = ~S"""
      (defmodule Derie)
      """

      assert {:ok,
              [
                [{:atom, 1, :defmodule}, {:symbol, 1, :Derie}]
              ]} == Parser.parse(code)
    end

    test "0 arg basic function" do
      code = ~S"""
      (defmodule Derie)
      (def name [] Integer 0)
      """

      assert {:ok,
              [
                [{:atom, 1, :defmodule}, {:symbol, 1, :Derie}],
                [
                  {:atom, 2, :def},
                  {:atom, 2, :name},
                  [],
                  {:symbol, 2, :Integer},
                  {:integer, 2, 0}
                ]
              ]} == Parser.parse(code)
    end

    test "0 arg function calls function" do
      code = ~S"""
      (defmodule Derie)
      (def name [] Integer (+ 1 2))
      """

      assert {:ok,
              [
                [{:atom, 1, :defmodule}, {:symbol, 1, :Derie}],
                [
                  {:atom, 2, :def},
                  {:atom, 2, :name},
                  [],
                  {:symbol, 2, :Integer},
                  [{:atom, 2, :+}, {:integer, 2, 1}, {:integer, 2, 2}]
                ]
              ]} == Parser.parse(code)
    end

    test "1 arity function" do
      code = ~S"""
      (def name ['x Integer] Integer x)
      """

      assert {:ok,
              [
                [
                  {:atom, 1, :def},
                  {:atom, 1, :name},
                  [{:symbol, 1, :x}, {:symbol, 1, :Integer}],
                  {:symbol, 1, :Integer},
                  {:atom, 1, :x}
                ]
              ]} = Parser.parse(code)
    end

    test "string literal" do
      code = ~S"""
      (def name [] String "abc")
      """

      assert {:ok,
              [
                [
                  {:atom, 1, :def},
                  {:atom, 1, :name},
                  [],
                  {:symbol, 1, :String},
                  {:string, 1, "abc"}
                ]
              ]} = Parser.parse(code)
    end
  end
end
