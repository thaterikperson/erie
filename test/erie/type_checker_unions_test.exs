defmodule Erie.TypeCheckerUnionTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator, TypeChecker}

  describe "no parameters" do
    test "basic" do
      code = """
      (deftype IntegerOrString []
        (union [Integer String]))
      (doc identity [IntegerOrString] IntegerOrString)
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
      (doc one [] IntegerOrString)
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
      (doc identity [(Ok Integer)] (Ok Integer))
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
      (doc ok [] (Ok Integer))
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
      (doc ok [] (Ok Integer))
      (def ok [] {'ok "0"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end

    test "literal doesn't match parameter" do
      code = """
      (deftype IntOrWhat [a]
        (union [Integer a]))
      (doc one [] (IntOrWhat String))
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
      (doc one [] (IntOrWhat String))
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
      (doc one [] (IntOrWhat String))
      (def one [] "1")
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "same parameter type 2" do
      code = """
      (deftype IntOrWhat [a]
        (union [Integer a {'ok a}]))
      (doc one [] (IntOrWhat String))
      (def one [] {'ok "1"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end
  end

  describe "user defined" do
    test "fails on undefined parameter type" do
      code = """
      (doc identity [(Result Integer String)] Integer)
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
      (doc identity [Integer] (Result Integer String))
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
      (doc identity [(Result Integer String)] (Result Integer String))
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end
  end

  describe "nested types" do
    test "basic nested" do
      code = """
      (deftype OkError []
        (union ['ok 'error]))
      (deftype OkErrorNone []
        (union [OkError 'none]))
      (doc identity [OkErrorNone] OkErrorNone)
      (def identity [x] x)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "nested parameterized" do
      code = """
      (deftype OkOrWhat [a]
        (union ['ok a]))
      (deftype OkOrWhatOrNone [b]
        (union [(OkOrWhat b) 'none]))
      (doc identity [(OkOrWhatOrNone String)] (OkOrWhatOrNone String))
      (def identity [x] x)
      (doc none [] (OkOrWhatOrNone (Tuple String Integer)))
      (def none [] 'none)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "nested parameterized 2" do
      code = """
      (deftype OkOrWhat [a]
        (union ['ok a]))
      (deftype OkOrWhatOrNone [b]
        (union [(OkOrWhat b) 'none]))
      (doc none [] (OkOrWhatOrNone (Tuple String Integer)))
      (def none [] 'ok)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "nested multiple parameterized" do
      code = """
      (deftype Either [a b]
        (union [a b]))
      (deftype Threither [a b c]
        (union [(Either b c) (Either a b)]))
      (doc none [] (Threither Integer String Float))
      (def none [] 0)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "complicated" do
      code = """
      (deftype StepOne [a b]
        (union [(Tuple Integer Integer) (Tuple String b)]))
      (deftype StepTwo [a b]
        (union [(StepOne a b) (Tuple 'ok String)]))
      (deftype StepThree [a b]
        (union [(StepTwo 'none Integer) (StepOne b a)]))
      (doc none [] (StepThree String Float))
      (def none [] {'ok "ok"})
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert :ok == TypeChecker.check(translator)
    end

    test "fails on undefined nested type" do
      code = """
      (deftype OkOrWhat [a]
        (union ['ok a]))
      (deftype OkOrWhatOrNone [b]
        (union [(OkError b) 'none]))
      (doc identity [(OkOrWhatOrNone String)] (OkOrWhatOrNone String))
      (def identity [x] x)
      (doc none [] (OkOrWhatOrNone (Tuple String Integer)))
      (def none [] 'none)
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert_raise RuntimeError, fn ->
        TypeChecker.check(translator)
      end
    end

    # need another test with deeper and wider polymorph tree.
    #
    # also, before: {{:Union, :Ok}, [:a], [Tuple: [:ok, :a]]}
    # need to figure that out. Is that 'ok or type parameter
    # named ok?
  end
end
