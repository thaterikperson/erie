defmodule Erie.TranslatorTypesTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator}

  describe "builtins" do
    test "list type" do
      code = """
      (deftype StringList []
        (union [(List String)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.types == [
               {{:Union, :StringList}, [], [{:ListInvocation, :String}]}
             ]
    end

    # test "literal list type" do
    #   code = """
    #   (deftype StringList []
    #     (union [[String]]))
    #   """

    #   {:ok, forms} = Parser.parse(code)
    #   translator = Translator.from_parsed(forms, {:Core, 1}, false)

    #   assert translator.types == [
    #            {{:Union, :StringList}, [], [{:ListInvocation, :String}]}
    #          ]
    # end

    test "tuple type" do
      code = """
      (deftype StringTuple []
        (union [(Tuple String String)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.types == [
               {{:Union, :StringTuple}, [], [{:TupleInvocation, [:String, :String]}]}
             ]
    end

    test "literal tuple type" do
      code = """
      (deftype StringTuple []
        (union [{String String}]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.types == [
               {{:Union, :StringTuple}, [], [{:TupleInvocation, [:String, :String]}]}
             ]
    end
  end

  describe "deftype" do
    test "advanded tuple type" do
      code = """
      (deftype IntOrWhat [a]
        (union [Integer a {'ok a}]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.types == [
               {{:Union, :IntOrWhat}, [:a],
                [:Integer, :a, {:TupleInvocation, [{:Symbol, :ok}, :a]}]}
             ]
    end

    test "nested unions" do
      code = """
      (deftype U1 [a b]
        (union [{'x a} {'y b}]))
      (deftype U2 [c]
        (union [{'z c} (U1 String Integer)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.types == [
               {{:Union, :U1}, [:a, :b],
                [{:TupleInvocation, [{:Symbol, :x}, :a]}, {:TupleInvocation, [{:Symbol, :y}, :b]}]},
               {{:Union, :U2}, [:c],
                [
                  {:TupleInvocation, [{:Symbol, :z}, :c]},
                  {{:UnionInvocation, :U1}, [:String, :Integer]}
                ]}
             ]
    end
  end
end
