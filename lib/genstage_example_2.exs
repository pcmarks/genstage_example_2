alias Experimental.GenStage
defmodule GenstageExample2 do
  @moduledoc """
  This is an example of a simple four stage GenStage flow. It features a
  multi-input stage - an adder that requires two values and computes their sum.

  The example is meant to illustrate how to
  1. design a multi-input stage, and
  2. allow for the uneven appearances of input events.

  ## To run:

  1. cd genstage_example_2
  2. mix run lib/genstage_example_2.exs
  """
  defmodule Constant do
    @moduledoc """
    """
    use GenStage
    def init(constant) do
      {:producer, constant}
    end
    def handle_demand(demand, constant) when demand > 0 do
      events = List.duplicate(constant, demand)
      {:noreply, events, constant}
    end
  end

  defmodule Sum do
    use GenStage

    def init(_) do
      {:producer_consumer, %{}}
    end
    def handle_subscribe(:consumer, _opts, _to_or_from, state) do
      {:automatic, state}
    end
    @doc """
    Capture information about stages that are plugged into Sum's inports
    """
    def handle_subscribe(:producer, opts, {_pid, tag}, state) do
      inport = Keyword.get(opts, :inport)
      case inport do
        nil ->
          {:stop, "no inport specified", state}
        _ ->
          new_state = Map.put(state, inport, {tag, []})
          {:automatic, new_state}
      end
    end

    def handle_events(events, {_pid, tag}, %{:addend => {tag, _}} = state) do
      # We are assuming that the subscription exists
      state = Map.update!(state, :addend,
          fn({tag, addends}) -> {tag, addends ++ events} end)
      {return_events, new_state} = do_sum(state)
      {:noreply, return_events, new_state}
    end
    def handle_events(events, {_pid, tag}, %{:augend => {tag, _}} = state) do
      # We are assuming that the subscription exists
      state = Map.update!(state, :augend,
            fn({tag, augends}) -> {tag, augends ++ events} end)
      {return_events, new_state} = do_sum(state)
      {:noreply, return_events, new_state}
    end
    defp do_sum(state) do
      {augend_tag, augends} = Map.get(state, :augend, {nil, []})
      {addend_tag, addends} = Map.get(state, :addend, {nil, []})
      {addends, augends, results} = sum_inports(addends, augends, [])
      state = Map.put(state, :addend, {addend_tag, addends})
      state = Map.put(state, :augend, {augend_tag, augends})
      {results, state}
    end
    defp sum_inports([], augends, results) do
      {[], augends, results}
    end
    defp sum_inports(addends, [], results) do
      {addends, [], results}
    end
    defp sum_inports([h_addends|t_addends], [h_augends|t_augends], results) do
      sum_inports(t_addends, t_augends, results ++ [h_addends + h_augends])
    end

  end

  defmodule Ticker do
    use GenStage
    def init(sleeping_time) do
      {:consumer, sleeping_time}
    end
    def handle_events(events, from, sleeping_time) do
      IO.puts "Ticker events: #{inspect events}"
      Process.sleep(sleeping_time)
      {:noreply, [], sleeping_time}
    end
  end

  # {:ok, addend} = GenStage.start_link(Constant, 3)
  # {:ok, augend} = GenStage.start_link(Constant, 4)
  {:ok, addend} = GenStage.from_enumerable([1,2,3])
  {:ok, augend} = GenStage.from_enumerable([3,4,5,7])
  {:ok, sum}    = GenStage.start_link(Sum, 0)
  {:ok, ticker} = GenStage.start_link(Ticker, 5_000)

  GenStage.sync_subscribe(ticker, to: sum)
  GenStage.sync_subscribe(sum, to: augend, inport: :augend)
  GenStage.sync_subscribe(sum, to: addend, inport: :addend)

  Process.sleep(:infinity)

end
