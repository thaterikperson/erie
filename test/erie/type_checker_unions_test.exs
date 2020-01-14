defmodule Erie.TypeCheckerUnionTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator, TypeChecker}

  describe "no parameters" do
    test "basic" do
      code = """
      (deftype IntegerOrString []
        (union [Integer String]))
      (sig identity [IntegerOrString] IntegerOrString)
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "return value" do
      code = """
      (deftype IntegerOrString []
        (union [Integer String]))
      (sig one [] IntegerOrString)
      (def one [] 1)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end
  end

  describe "parameters" do
    test "basic tuple" do
      code = """
      (deftype Ok [a]
        (union [{'ok a}]))
      (sig identity [(Ok Integer)] (Ok Integer))
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "tuple return" do
      code = """
      (deftype Ok [a]
        (union [(Tuple 'ok a)]))
      (sig ok [] (Ok Integer))
      (def ok [] {'ok 0})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "fails on wrong type tuple return" do
      code = """
      (deftype Ok [a]
        (union [(Tuple 'ok a)]))
      (sig ok [] (Ok Integer))
      (def ok [] {'ok "0"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "literal doesn't match parameter" do
      code = """
      (deftype IntOrWhat [a]
        (union [Integer a]))
      (sig one [] (IntOrWhat String))
      (def one [] 1)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "literal matches parameter" do
      code = """
      (deftype IntOrWhat [a]
        (union [Integer a]))
      (sig one [] (IntOrWhat String))
      (def one [] "1")
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "same parameter type" do
      code = """
      (deftype IntOrWhat [a]
        (union [Integer a {'ok a}]))
      (sig one [] (IntOrWhat String))
      (def one [] "1")
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end
  end

  describe "user defined" do
    test "fails on undefined parameter type" do
      code = """
      (sig identity [(Result Integer String)] Integer)
      (def identity [x] 0)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end

    test "fails on undefined return type" do
      code = """
      (sig identity [Integer] (Result Integer String))
      (def identity [x] {'ok x})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end

    test "fails on incorrectly defined type" do
      code = """
      (deftype Result [a e f]
        (union [{'ok a} {'error e} {'other f}]))
      (sig identity [(Result Integer String)] (Result Integer String))
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end
  end
end
