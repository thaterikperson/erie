defmodule Erie do
  use GenServer

  def start_link(config) do
    GenServer.start_link(__MODULE__, config)
  end

  def init(config) do
    # do_all()

    {:ok, config}
  end

  def do_all() do
    dir = File.cwd!()
    file = Path.join(dir, "app.erie")

    with {:ok, forms} <- Erie.Parser.parse_file(file),
         {:ok, ast} <- Erie.Translator.to_ast(forms) do
      {:ok, m, b} = :compile.forms(ast)

      :code.load_binary(m, 'nofile', b)

      IO.puts("================")
      IO.inspect(apply(:"Erie.Derie", :name, []))
      IO.puts("================")
    else
      x -> IO.warn(inspect(x))
    end
  end
end
