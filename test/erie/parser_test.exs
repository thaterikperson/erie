defmodule ParserTest do
  use ExUnit.Case
  alias Erie.Parser
  doctest Erie.Parser

  describe "tokenizer" do
    test "defmodule" do
      code = ~S"""
      (defmodule Derie)
      """

      assert {:ok, [{:"(", 1}, {:atom, 1, :defmodule}, {:symbol, 1, :Derie}, {:")", 1}], 2} ==
               Parser.tokenize(code)
    end

    test "1 arity function" do
      code = ~S"""
      (sig name Integer Integer)
      (def name [x] x)
      """

      assert {:ok,
              [
                {:"(", 1},
                {:atom, 1, :sig},
                {:atom, 1, :name},
                {:symbol, 1, :Integer},
                {:symbol, 1, :Integer},
                {:")", 1},
                {:"(", 2},
                {:atom, 2, :def},
                {:atom, 2, :name},
                {:"[", 2},
                {:atom, 2, :x},
                {:"]", 2},
                {:atom, 2, :x},
                {:")", 2}
              ], 3} == Parser.tokenize(code)
    end

    test "literals" do
      code = ~S"""
      (sig literals Any)
      (def literals []
        {"abc" [1 2 3 4]})
      """

      assert {:ok,
              [
                {:"(", 1},
                {:atom, 1, :sig},
                {:atom, 1, :literals},
                {:symbol, 1, :Any},
                {:")", 1},
                {:"(", 2},
                {:atom, 2, :def},
                {:atom, 2, :literals},
                {:"[", 2},
                {:"]", 2},
                {:"{", 3},
                {:string, 3, "abc"},
                {:"[", 3},
                {:integer, 3, 1},
                {:integer, 3, 2},
                {:integer, 3, 3},
                {:integer, 3, 4},
                {:"]", 3},
                {:"}", 3},
                {:")", 3}
              ], 4} == Parser.tokenize(code)
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
      (sig name Integer)
      (def name [] 0)
      """

      assert {:ok,
              [
                [{:atom, 1, :defmodule}, {:symbol, 1, :Derie}],
                [{:atom, 2, :sig}, {:atom, 2, :name}, {:symbol, 2, :Integer}],
                [
                  {:atom, 3, :def},
                  {:atom, 3, :name},
                  {:list, 3, []},
                  {:integer, 3, 0}
                ]
              ]} == Parser.parse(code)
    end

    test "0 arg function calls function" do
      code = ~S"""
      (defmodule Derie)
      (sig name Integer)
      (def name [] (+ 1 2))
      """

      assert {:ok,
              [
                [{:atom, 1, :defmodule}, {:symbol, 1, :Derie}],
                [{:atom, 2, :sig}, {:atom, 2, :name}, {:symbol, 2, :Integer}],
                [
                  {:atom, 3, :def},
                  {:atom, 3, :name},
                  {:list, 3, []},
                  [{:atom, 3, :+}, {:integer, 3, 1}, {:integer, 3, 2}]
                ]
              ]} == Parser.parse(code)
    end

    test "1 arity function" do
      code = ~S"""
      (sig name Integer Integer)
      (def name [x] x)
      """

      assert {:ok,
              [
                [
                  {:atom, 1, :sig},
                  {:atom, 1, :name},
                  {:symbol, 1, :Integer},
                  {:symbol, 1, :Integer}
                ],
                [
                  {:atom, 2, :def},
                  {:atom, 2, :name},
                  {:list, 2, [{:atom, 2, :x}]},
                  {:atom, 2, :x}
                ]
              ]} == Parser.parse(code)
    end

    test "literals" do
      code = ~S"""
      (sig literals Any)
      (def literals []
        {"abc" [] [1 2 3 4]})
      """

      assert {:ok,
              [
                [
                  {:atom, 1, :sig},
                  {:atom, 1, :literals},
                  {:symbol, 1, :Any}
                ],
                [
                  {:atom, 2, :def},
                  {:atom, 2, :literals},
                  {:list, 2, []},
                  {:tuple, 3,
                   [
                     {:string, 3, "abc"},
                     {:list, 3, []},
                     {:list, 3,
                      [
                        {:integer, 3, 1},
                        {:integer, 3, 2},
                        {:integer, 3, 3},
                        {:integer, 3, 4}
                      ]}
                   ]}
                ]
              ]} == Parser.parse(code)
    end
  end
end
