defmodule Erie.Builtin do
  def types() do
    [
      :Boolean,
      :Float,
      :Integer,
      :String,
      {:List, :a},
      {:Tuple, [:a, :b]},
      {:Tuple, [:a, :b, :c]},
      {:Tuple, [:a, :b, :c, :d]},
      {:Tuple, [:a, :b, :c, :d, :e]},
      {:Tuple, [:a, :b, :c, :d, :e, :f]},
      {:Tuple, [:a, :b, :c, :d, :e, :f, :g]},
      {:Tuple, [:a, :b, :c, :d, :e, :f, :g, :h]}
    ]
  end

  def type_names() do
    [
      :Boolean,
      :Float,
      :Integer,
      :List,
      :String,
      :Tuple
    ]
  end
end
