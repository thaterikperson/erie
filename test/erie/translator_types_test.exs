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
               {{:Union, :StringList}, [], [{:List, [:String]}]}
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
    #            {{:Union, :StringList}, [], [{:List, [:String]}]}
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
               {{:Union, :StringTuple}, [], [{:Tuple, [:String, :String]}]}
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
               {{:Union, :StringTuple}, [], [{:Tuple, [:String, :String]}]}
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
               {{:Union, :IntOrWhat}, [:a], [:Integer, :a, {:Tuple, [:ok, :a]}]}
             ]
    end
  end
end
