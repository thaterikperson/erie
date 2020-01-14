defmodule Erie.TranslatorSignatureTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator}

  describe "builtin types" do
    test "basic types" do
      code = """
      (sig one [] Integer)
      (def one [] 1)
      (sig two [String String] String)
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
      (sig identity [{String Integer}] {String Integer})
      (def identity [x] x)
      (sig one [] {String String})
      (def one []
        {"x" "y"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:identity, {[{:String, :Integer}], {:String, :Integer}}},
               {:one, {[], {:String, :String}}}
             ]
    end

    test "list types" do
      code = """
      (sig identity [[String]] [String])
      (def identity [x] x)
      (sig one [] [Integer])
      (def one []
        [1 2 3])
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:identity, {[[:String]], [:String]}},
               {:one, {[], [:Integer]}}
             ]
    end
  end

  describe "union types" do
    test "basic" do
      code = """
      (deftype IntegerOrString []
        (union [Integer String]))
      (sig identity [IntegerOrString] IntegerOrString)
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:identity, {[:IntegerOrString], :IntegerOrString}}
             ]
    end

    test "polymorphic" do
      code = """
      (deftype Result [a e]
        (union [{'ok a} {'error e}]))
      (sig identity [(Result Integer String)] (Result Integer String))
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert translator.signatures == [
               {:identity, {[{:Result, [:Integer, :String]}], {:Result, [:Integer, :String]}}}
             ]
    end
  end
end
