defmodule TranslatorTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator}
  doctest Erie.Parser

  test "literals" do
    code = """
    (defmodule Core)
    (sig literals Any)
    (def literals []
      {"abc" [] nil [1 2 3]})
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Core"},
              {:attribute, 1, :export, [literals: 0]},
              {:function, 3, :literals, 0,
               [
                 {:clause, 3, [], [],
                  [
                    {:tuple, 4,
                     [
                       {:bin, 4, [{:bin_element, 4, {:string, 4, 'abc'}, :default, :default}]},
                       {nil, 4},
                       {:atom, 4, nil},
                       {:cons, 4, {:integer, 4, 1},
                        {:cons, 4, {:integer, 4, 2}, {:cons, 4, {:integer, 4, 3}, {nil, 4}}}}
                     ]}
                  ]}
               ]}
            ]} == Translator.to_eaf(forms)
  end

  test "0 arity" do
    code = """
    (defmodule Derie)
    (sig name Integer)
    (def name [] 1)
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Derie"},
              {:attribute, 1, :export, [name: 0]},
              {:function, 3, :name, 0,
               [
                 {:clause, 3, [], [], [{:integer, 3, 1}]}
               ]}
            ]} == Translator.to_eaf(forms)
  end

  test "1 arity" do
    code = """
    (defmodule Derie)
    (sig name Integer Integer)
    (def name [x] x)
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Derie"},
              {:attribute, 1, :export, [name: 1]},
              {:function, 3, :name, 1,
               [
                 {:clause, 3, [{:var, 3, :x}], [], [{:var, 3, :x}]}
               ]}
            ]} == Translator.to_eaf(forms)
  end

  test "local function call" do
    code = """
    (defmodule Core)
    (sig identity Integer Integer)
    (def identity [x] x)
    (sig again Integer)
    (def again []
      (identity 3))
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Core"},
              {:attribute, 1, :export, [identity: 1, again: 0]},
              {:function, 3, :identity, 1,
               [
                 {:clause, 3, [{:var, 3, :x}], [], [{:var, 3, :x}]}
               ]},
              {:function, 5, :again, 0,
               [
                 {:clause, 5, [], [],
                  [
                    {:call, 6, {:atom, 6, :identity}, [{:integer, 6, 3}]}
                  ]}
               ]}
            ]} == Translator.to_eaf(forms)
  end

  test "Elixir function call" do
    code = """
    (defmodule Core)
    (sig split_by_comma String String)
    (def split_by_comma [str]
      (Elixir.String.split str ","))
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Core"},
              {:attribute, 1, :export, [{:split_by_comma, 1}]},
              {:function, 3, :split_by_comma, 1,
               [
                 {:clause, 3, [{:var, 3, :str}], [],
                  [
                    {:call, 4, {:remote, 4, {:atom, 4, :"Elixir.String"}, {:atom, 4, :split}},
                     [
                       {:var, 4, :str},
                       {:bin, 4, [{:bin_element, 4, {:string, 4, ','}, :default, :default}]}
                     ]}
                  ]}
               ]}
            ]} == Translator.to_eaf(forms)
  end

  test "case" do
    code = """
    (defmodule Core)
    (sig split_by String Symbol String)
    (def split_by [str kind]
      (case kind
        ['comma str]
        ['whitespace str]
        [_ str]))
    """

    {:ok, forms} = Parser.parse(code)

    assert {:ok,
            [
              {:attribute, 1, :module, :"Erie.Core"},
              {:attribute, 1, :export, [{:split_by, 2}]},
              {:function, 3, :split_by, 2,
               [
                 {:clause, 3, [{:var, 3, :str}, {:var, 3, :kind}], [],
                  [
                    {:case, 4, {:var, 4, :kind},
                     [
                       {:clause, 5, [{:atom, 5, :comma}], [], [{:var, 5, :str}]},
                       {:clause, 6, [{:atom, 6, :whitespace}], [], [{:var, 6, :str}]},
                       {:clause, 7, [{:var, 7, :_}], [], [{:var, 7, :str}]}
                     ]}
                  ]}
               ]}
            ]} == Translator.to_eaf(forms)
  end

  describe "lambda" do
    test "as a parameter to a function" do
      code = """
      (defmodule Core)
      (sig lambdas (List Integer))
      (def lambdas []
        (Elixir.Enum.map [1] (lambda [x] x)))
      """

      {:ok, forms} = Parser.parse(code)

      assert {:ok,
              [
                {:attribute, 1, :module, :"Erie.Core"},
                {:attribute, 1, :export, [{:lambdas, 0}]},
                {:function, 3, :lambdas, 0,
                 [
                   {:clause, 3, [], [],
                    [
                      {:call, 4, {:remote, 4, {:atom, 4, :"Elixir.Enum"}, {:atom, 4, :map}},
                       [
                         {:cons, 4, {:integer, 4, 1}, {nil, 4}},
                         {:fun, 4,
                          {:clauses, [{:clause, 4, [{:var, 4, :x}], [], [{:var, 4, :x}]}]}}
                       ]}
                    ]}
                 ]}
              ]} == Translator.to_eaf(forms)
    end

    test "executed anonymously" do
      code = """
      (defmodule Core)
      (sig lambdas Integer)
      (def lambdas []
        ((lambda [x] x) 1))
      """

      {:ok, forms} = Parser.parse(code)

      assert {:ok,
              [
                {:attribute, 1, :module, :"Erie.Core"},
                {:attribute, 1, :export, [{:lambdas, 0}]},
                {:function, 3, :lambdas, 0,
                 [
                   {:clause, 3, [], [],
                    [
                      {:call, 4,
                       {:fun, 4,
                        {:clauses, [{:clause, 4, [{:var, 4, :x}], [], [{:var, 4, :x}]}]}},
                       [{:integer, 4, 1}]}
                    ]}
                 ]}
              ]} == Translator.to_eaf(forms)
    end
  end
end
