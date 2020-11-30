defmodule Erie.TypeCheckerTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator, TypeChecker}

  describe "parameter checks" do
    test "basic function" do
      code = """
      (doc identity [String] String)
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "local function call" do
      code = """
      (doc identity [String] String)
      (def identity [x] x)
      (doc call_it [String] String)
      (def call_it [y]
        (identity y))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "local function call with literal" do
      code = """
      (doc identity [String] String)
      (def identity [x] x)
      (doc call_it [] String)
      (def call_it []
        (identity "y"))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "fails on incorrect parameters to local function call" do
      code = """
      (doc identity [String] String)
      (def identity [x] x)
      (doc call_it [Integer] String)
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
      (doc one [] Integer)
      (def one [] 1)
      (doc two [] String)
      (def two [] "2")
      (doc tup [] (Tuple Integer String))
      (def tup [] {1 "2"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "literal list type" do
      code = """
      (doc four [] (List Integer))
      (def four []
        [1 2 3 4])
      (doc one [] (List Integer))
      (def one []
        [1])
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "literal list type fails with mismatched types" do
      code = """
      (doc one [] (List Integer))
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
      (doc none [] (List Integer))
      (def none []
        [])
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "local function call" do
      code = """
      (doc one [] Integer)
      (def one [] 1)
      (doc one_one [] Integer)
      (def one_one []
        (one))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "fails on incorrect return value of local function call" do
      code = """
      (doc identity [String] String)
      (def identity [x] x)
      (doc call_it [String] Integer)
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

  describe "signature_type_exists?" do
    test "0 param union exists" do
      assert TypeChecker.signature_type_exists?({{:UnionInvocation, :SimpleResult}, []}, [
               {{:Union, :SimpleResult}, [], [Symbol: :ok, Symbol: :error]}
             ])
    end

    test "one param union exists" do
      assert TypeChecker.signature_type_exists?(
               {{:UnionInvocation, :Maybe}, [:String]},
               [
                 {{:Union, :Maybe}, [:a], [{:Symbol, nil}, :a]}
               ]
             )
    end

    test "multi-param union exists" do
      assert TypeChecker.signature_type_exists?(
               {{:UnionInvocation, :Either}, [:Integer, :String]},
               [
                 {{:Union, :Either}, [:a, :b], [:a, :b]}
               ]
             )
    end
  end
end
