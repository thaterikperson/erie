defmodule Erie.TypeExpanderTest do
  use ExUnit.Case
  alias Erie.{Parser, Translator, TypeExpander}

  describe "expand_invocation" do
    test "single expansion" do
      code = """
      (deftype StepOne [a b]
        (union [(Tuple Integer Integer)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepOne}, [{:TupleInvocation, [:Integer, :Integer]}]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepOne}, [:String, :Float]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "single expansion with replacement" do
      code = """
      (deftype StepOne [a]
        (union [(Tuple a Integer)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepOne}, [{:TupleInvocation, [:String, :Integer]}]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepOne}, [:String]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "single expansion with duplicate replacement" do
      code = """
      (deftype StepOne [a]
        (union [(Tuple a a)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepOne}, [{:TupleInvocation, [:String, :String]}]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepOne}, [:String]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "single expansion with swapped replacement" do
      code = """
      (deftype StepOne [a b]
        (union [(Tuple b a Integer b)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepOne},
              [{:TupleInvocation, [:Float, :String, :Integer, :Float]}]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepOne}, [:String, :Float]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "double expansion" do
      code = """
      (deftype StepOne [a b]
        (union [(Tuple Integer Integer)]))
      (deftype StepTwo [a b]
        (union [(StepOne String Float)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepTwo},
              [
                {:TupleInvocation, [:Integer, :Integer]}
              ]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepTwo}, [:String, :Float]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "double expansion with replacement" do
      code = """
      (deftype StepOne [a b]
        (union [(Tuple a b) (Tuple b a)]))
      (deftype StepTwo [a]
        (union [(StepOne a Float)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepTwo},
              [
                {:TupleInvocation, [:Float, :String]},
                {:TupleInvocation, [:String, :Float]}
              ]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepTwo}, [:String]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "triple expansion" do
      code = """
      (deftype StepOne [a b]
        (union [(Tuple Integer Integer)]))
      (deftype StepTwo [a b]
        (union [(StepOne a b)]))
      (deftype StepThree [a b]
        (union [(StepTwo 'none Integer)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepThree},
              [
                {:TupleInvocation, [:Integer, :Integer]}
              ]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepThree}, [:String, :Float]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "multi-level expansion" do
      code = """
      (deftype StepOne [a b]
        (union [(Tuple Integer Integer) (Tuple String b)]))
      (deftype StepTwo [a b]
        (union [(StepOne a b) (Tuple 'ok String)]))
      (deftype StepThree [a b]
        (union [(StepTwo 'none Integer) (StepOne b a)]))
      """

      {:ok, forms} = Parser.parse(code)
      translator = Translator.from_parsed(forms, {:Core, 1}, false)

      assert {{:UnionInvocation, :StepThree},
              [
                {:TupleInvocation, [:String, :Float]},
                {:TupleInvocation, [:Integer, :Integer]},
                {:TupleInvocation, [{:Symbol, :ok}, :String]},
                {:TupleInvocation, [:String, :Integer]},
                {:TupleInvocation, [:Integer, :Integer]}
              ]} ==
               TypeExpander.expand_invocation(
                 {{:UnionInvocation, :StepThree}, [:Float, :Boolean]},
                 Erie.Builtin.types() ++ translator.types
               )
    end

    test "recursive expansion stops" do
      flunk("implement me")
    end
  end
end
