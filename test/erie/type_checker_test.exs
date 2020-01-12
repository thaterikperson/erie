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

  describe "parameter checks" do
    test "basic function" do
      code = """
      (sig identity [String] String)
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "local function call" do
      code = """
      (sig identity [String] String)
      (def identity [x] x)
      (sig call_it [String] String)
      (def call_it [y]
        (identity y))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "local function call with literal" do
      code = """
      (sig identity [String] String)
      (def identity [x] x)
      (sig call_it [] String)
      (def call_it []
        (identity "y"))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "fails on incorrect parameters to local function call" do
      code = """
      (sig identity [String] String)
      (def identity [x] x)
      (sig call_it [Integer] String)
      (def call_it [y]
        (identity y))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end
  end

  describe "return value checks" do
    test "literal value" do
      code = """
      (sig one [] Integer)
      (def one [] 1)
      (sig two [] String)
      (def two [] "2")
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "local function call" do
      code = """
      (sig one [] Integer)
      (def one [] 1)
      (sig one_one [] Integer)
      (def one_one []
        (one))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "fails on incorrect return value of local function call" do
      code = """
      (sig identity [String] String)
      (def identity [x] x)
      (sig call_it [String] Integer)
      (def call_it [y]
        (identity y))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end
  end
end
