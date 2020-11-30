defmodule Erie.TranslatorSignatureTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator}

  describe "builtin types" do
    test "basic types" do
      code = """
      (doc one [] Integer)
      (def one [] 1)
      (doc two [String String] String)
      (def two [x y] y)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:one, {[], :Integer}},
               {:two, {[:String, :String], :String}}
             ]
    end

    test "tuple types" do
      code = """
      (doc identity [{String Integer}] {String Integer})
      (def identity [x] x)
      (doc one [] {String String})
      (def one []
        {"x" "y"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:identity,
                {[{:TupleInvocation, [:String, :Integer]}],
                 {:TupleInvocation, [:String, :Integer]}}},
               {:one, {[], {:TupleInvocation, [:String, :String]}}}
             ]
    end

    test "list types" do
      code = """
      (doc parameter [(List String)] (List String))
      (def parameter [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:parameter, {[{:ListInvocation, :String}], {:ListInvocation, :String}}}
             ]
    end
  end

  describe "union types" do
    test "basic" do
      code = """
      (deftype IntegerOrString []
        (union [Integer String]))
      (doc identity [IntegerOrString] IntegerOrString)
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:identity,
                {[{{:UnionInvocation, :IntegerOrString}, []}],
                 {{:UnionInvocation, :IntegerOrString}, []}}}
             ]
    end

    test "polymorphic" do
      code = """
      (deftype Result [a e]
        (union [{'ok a} {'error e}]))
      (doc identity [(Result Integer String)] (Result Integer String))
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)

      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:identity,
                {[{{:UnionInvocation, :Result}, [:Integer, :String]}],
                 {{:UnionInvocation, :Result}, [:Integer, :String]}}}
             ]
    end
  end
end
