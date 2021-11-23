alias LimitedQueue, as: Queue

defmodule BenchQueue do
  def make_list(size) do
    1..size
    |> Enum.reduce([], fn i, list ->
      [i | list]
    end)
  end

  def append(%Queue{capacity: capacity, size: capacity} = state, events) do
    {state, length(events)}
  end

  def append(%Queue{} = state, events) do
    Enum.reduce(events, {state, 0}, fn event, {state, dropped} ->
      case push(state, event) do
        {:ok, state} ->
          {state, dropped}

        {:error, :full} ->
          {state, dropped + 1}
      end
    end)
  end

  def append_erlang(%Queue{capacity: capacity, size: capacity} = state, events) do
    {state, length(events)}
  end

  def append_erlang(%Queue{} = state, events) do
    events_count = length(events)
    max_append = state.capacity - state.size

    {events, events_count, dropped} =
      if events_count > max_append do
        dropped = events_count - max_append
        events = Enum.take(events, max_append)
        {events, max_append, dropped}
      else
        {events, events_count, 0}
      end

    events_queue = :queue.from_list(events)
    queue = :queue.join(events_queue, state.queue)
    state = %Queue{state | queue: queue, size: state.size + events_count}
    {state, dropped}
  end

  def append_erlang2(%Queue{capacity: capacity, size: capacity} = state, events) do
    {state, length(events)}
  end

  def append_erlang2(%Queue{} = state, events) do
    events_queue = :queue.from_list(events)
    events_count = :queue.len(events_queue)
    max_append = state.capacity - state.size

    {events_queue, events_count, dropped_count} =
      if events_count > max_append do
        dropped_count = events_count - max_append
        {events_queue, _dropped} = :queue.split(max_append, events_queue)
        {events_queue, max_append, dropped_count}
      else
        {events_queue, events_count, 0}
      end

    queue = :queue.join(events_queue, state.queue)
    state = %Queue{state | queue: queue, size: state.size + events_count}
    {state, dropped_count}
  end

  defp push(%Queue{capacity: capacity, size: capacity}, _element) do
    {:error, :full}
  end

  defp push(%Queue{} = state, element) do
    queue = :queue.in(element, state.queue)

    state = %Queue{
      state
      | queue: queue,
        size: state.size + 1
    }

    {:ok, state}
  end
end

queue = Queue.new(100)
list = BenchQueue.make_list(200)
{append_queue, append_dropped} = BenchQueue.append(queue, list)
{erlang_queue, erlang_dropped} = BenchQueue.append_erlang(queue, list)
{erlang_queue2, erlang_dropped2} = BenchQueue.append_erlang2(queue, list)

if Queue.to_list(append_queue) != Queue.to_list(erlang_queue) do
  IO.puts("original queue: #{inspect(Queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the resulting queues of different append implementations are not the same:

  #{inspect(append_queue, charlists: :as_lists)} != #{inspect(erlang_queue, charlists: :as_lists)}
  """
end

if Queue.to_list(append_queue) != Queue.to_list(erlang_queue2) do
  IO.puts("original queue: #{inspect(Queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the resulting queues of different append implementations are not the same:

  #{inspect(append_queue, charlists: :as_lists)} != #{
    inspect(erlang_queue2, charlists: :as_lists)
  }
  """
end

if append_dropped != erlang_dropped do
  IO.puts("original queue: #{inspect(Queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the drop results of different append implementations are not the same:

  #{append_dropped} != #{erlang_dropped}
  """
end

if append_dropped != erlang_dropped2 do
  IO.puts("original queue: #{inspect(Queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the drop results of different append implementations are not the same:

  #{append_dropped} != #{erlang_dropped2}
  """
end

Benchee.run(
  %{
    "Append with erlang queue from_list and Enum.take" => fn {queue, list} ->
      BenchQueue.append_erlang(queue, list)
    end,
    "Append using recursive elixir and push" => fn {queue, list} ->
      BenchQueue.append(queue, list)
    end,
    "Append with erlang queue from_list and :queue.split" => fn {queue, list} ->
      BenchQueue.append_erlang2(queue, list)
    end
  },
  inputs: %{
    "queue size 100, append 1" => {Queue.new(100), BenchQueue.make_list(1)},
    "queue size 100, append 100" => {Queue.new(100), BenchQueue.make_list(100)},
    "queue size 100, append 1_000" => {Queue.new(100), BenchQueue.make_list(1_000)},
    "queue size 10_000, append 1_000" => {Queue.new(10_000), BenchQueue.make_list(1_000)},
    "queue size 10_000, append 10_000" => {Queue.new(10_000), BenchQueue.make_list(10_000)},
    "queue size 10_000, append 100_000" => {Queue.new(10_000), BenchQueue.make_list(100_000)},
    "queue size 100_000, append 100_000" => {Queue.new(100_000), BenchQueue.make_list(100_000)}
  },
  formatters: [
    Benchee.Formatters.Console
  ],
  save: %{
    path: "bench/results/queue/runs"
  },
  time: 1
)
