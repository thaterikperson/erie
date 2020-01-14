defmodule Erie.TypeCheckerTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator, TypeChecker}

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
      (sig tup [] (Tuple Integer String))
      (def tup [] {1 "2"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "literal list type" do
      code = """
      (sig four [] (List Integer))
      (def four []
        [1 2 3 4])
      (sig one [] (List Integer))
      (def one []
        [1])
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "literal list type fails with mismatched types" do
      code = """
      (sig one [] (List Integer))
      (def one []
        [1 2 "3" 4])
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end

    test "literal empty list type" do
      code = """
      (sig none [] (List Integer))
      (def none []
        [])
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
