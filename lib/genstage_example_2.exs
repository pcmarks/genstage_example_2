alias Experimental.GenStage
defmodule GenstageExample2 do
  @moduledoc """
  This is an example of a simple four stage GenStage flow. It features a multi-input stage - an adder that requires two values and computes their sum. For a more detailed
  explanation, please see this blog [post](www.elixirfbp.com)

  The example is meant to illustrate how to
  1. design a multi-input stage, and
  2. allow for the uneven appearances of input events.

  Two examples of flows are possible - see the comments at the bottom for directions:
  1. Two Constant stages feed a Sum stage whose output is asked for by a
  Timer stage.
  2. Two enumerated flows feed a Sum stage whose output is asked for by a
  Timer stage.

  ## To run:

  1. cd genstage_example_2
  2. mix deps.get
  3. mix run lib/genstage_example_2.exs
  """
  defmodule Constant do
    @moduledoc """
    This stage will always produce demand number of values.
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
    @moduledoc """
    The Sum stage expects two input values at inports named :addend and :augend.
    It will produce the sum of as many pairs of inputs as possible. For example,
    the sum of [1,3,5] and [5,3] is [6,6] and the sum of [] and [2,4,6] is []
    """
    use GenStage

    def init(_not_used) do
      {:producer_consumer, %{:addend => {nil, []}, :augend => {nil, []}}}
    end
    @doc """
    This is actually the default but needs to be supplied because we are
    handling the producer subscriptions below.
    """
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
      {return_events, new_state} = sum_inports(state)
      {:noreply, return_events, new_state}
    end
    def handle_events(events, {_pid, tag}, %{:augend => {tag, _}} = state) do
      # We are assuming that the subscription exists
      state = Map.update!(state, :augend,
            fn({tag, augends}) -> {tag, augends ++ events} end)
      {return_events, new_state} = sum_inports(state)
      {:noreply, return_events, new_state}
    end
    defp sum_inports(state) do
      {augend_tag, augends} = Map.get(state, :augend, {nil, []})
      {addend_tag, addends} = Map.get(state, :addend, {nil, []})
      {addends, augends, results} = sum_inports(addends, augends, [])
      state = Map.put(state, :addend, {addend_tag, addends})
      state = Map.put(state, :augend, {augend_tag, augends})
      {results, state}
    end
    defp do_sum([], augends, results) do
      {[], augends, results}
    end
    defp do_sum(addends, [], results) do
      {addends, [], results}
    end
    defp do_sum([h_addends|t_addends], [h_augends|t_augends], results) do
      do_sum(t_addends, t_augends, results ++ [h_addends + h_augends])
    end

  end

  defmodule Ticker do
    @moduledoc """
    A Ticker stage waits for some number of milliseconds before asking for
    events. When an event is received it is printed.
    """
    use GenStage
    def init(sleeping_time) do
      {:consumer, sleeping_time}
    end
    def handle_events(events, _from, sleeping_time) do
      IO.puts "Ticker events: #{inspect(events, charlists: :as_lists)}"
      Process.sleep(sleeping_time)
      {:noreply, [], sleeping_time}
    end
  end

  {:ok, addend} = GenStage.start_link(Constant, 3)
  {:ok, augend} = GenStage.start_link(Constant, 4)
  {:ok, sum}    = GenStage.start_link(Sum, 0)
  {:ok, ticker} = GenStage.start_link(Ticker, 5_000)
  # Uncomment the next four code lines and comment out the four lines above
  # to use two enumerable flows as input to Sum
  # {:ok, addend} = GenStage.from_enumerable([1,2,3])
  # {:ok, augend} = GenStage.from_enumerable([3,4,5,7])
  # {:ok, sum}    = GenStage.start_link(Sum, 0)
  # {:ok, ticker} = GenStage.start_link(Ticker, 5_000)

  GenStage.sync_subscribe(ticker, to: sum, max_demand: 1)
  GenStage.sync_subscribe(sum, to: augend, inport: :augend)
  GenStage.sync_subscribe(sum, to: addend, inport: :addend)

  Process.sleep(:infinity)

end
