defmodule Erie.Repl do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def init(state) do
    {:ok, state, 0}
  end

  def handle_info(:timeout, state) do
    new_state =
      case IO.gets("#{state.module}(#{state.count})> ") do
        :eof ->
          IO.puts("Unexpected EOF")
          state

        {:error, reason} ->
          IO.puts("Got an error: #{inspect(reason)}")
          state

        code ->
          module = String.to_atom(Atom.to_string(state.module) <> Integer.to_string(state.count))

          case run(module, code) do
            {:ok, result} ->
              %{state | count: state.count + 1, results: [result | state.results]}

            :error ->
              IO.puts("Failed to get a result")
              state
          end
      end

    {:noreply, new_state, 0}
  end

  def run(module, code) do
    task = Task.async(__MODULE__, :eval, [module, code])

    case Task.yield(task) || Task.shutdown(task) do
      {:ok, result} ->
        {:ok, result}

      nil ->
        :error
    end
  end

  def eval(module, code) do
    case Erie.compile_and_eval(code, {module, 1}) do
      {:value, value, _bindings} ->
        IO.puts(inspect(value))

      :ok ->
        :ok
    end
  end
end
