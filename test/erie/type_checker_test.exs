defmodule Erie.TypeCheckerTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator, TypeChecker}

  describe "signature parsing" do
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

    test "polymorphic types" do
      assert "get to this later"
    end
  end

  test "inner function call checks" do
  end

  describe "return value checks" do
    test "literal value" do
      code = """
      (sig one [] Integer)
      (def x [] 1)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end
  end
end
