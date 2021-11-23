defmodule BenchQueue do
  def make_queue() do
    :queue.new()
  end

  def make_values(count) do
    Enum.reduce(1..count, [], fn i, acc -> [i | acc] end)
  end

  def split_then_join(queue, values, limit) do
    value_list = :queue.from_list(values)
    {_dropped_split, value_list} = :queue.split(limit, value_list)
    :queue.join(queue, value_list)
  end

  def take_then_join(queue, values, limit) do
    values = Enum.take(values, -limit)
    value_list = :queue.from_list(values)
    :queue.join(queue, value_list)
  end
end

queue = BenchQueue.make_queue()
values = BenchQueue.make_values(100)
split_queue = BenchQueue.split_then_join(queue, values, 50)
take_queue = BenchQueue.take_then_join(queue, values, 50)

if :queue.to_list(split_queue) != :queue.to_list(take_queue) do
  IO.puts("original queue: #{inspect(:queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the resulting queues of different implementations are not the same:

  #{inspect(split_queue, charlists: :as_lists)} != #{inspect(take_queue, charlists: :as_lists)}
  """
end

Benchee.run(
  %{
    "Limit with erlang queue split" => fn {queue, values, limit} ->
      BenchQueue.split_then_join(queue, values, limit)
    end,
    "Limit with elixir Enum.take" => fn {queue, values, limit} ->
      BenchQueue.take_then_join(queue, values, limit)
    end
  },
  inputs: %{
    "10 value, 1 limit" => {BenchQueue.make_queue(), BenchQueue.make_values(10), 1},
    "10 value, 5 limit" => {BenchQueue.make_queue(), BenchQueue.make_values(10), 5},
    "1_000 value, 1 limit" => {BenchQueue.make_queue(), BenchQueue.make_values(1_000), 1},
    "1_000 value, 250 limit" => {BenchQueue.make_queue(), BenchQueue.make_values(1_000), 250},
    "1_000 value, 1_000 limit" => {BenchQueue.make_queue(), BenchQueue.make_values(1_000), 1_000},
    "100_000 value, 1 limit" => {BenchQueue.make_queue(), BenchQueue.make_values(100_000), 1},
    "100_000 value, 1_000 limit" =>
      {BenchQueue.make_queue(), BenchQueue.make_values(100_000), 1_000},
    "100_000 value, 10_000 limit" =>
      {BenchQueue.make_queue(), BenchQueue.make_values(100_000), 10_000},
    "100_000 value, 100_000 limit" =>
      {BenchQueue.make_queue(), BenchQueue.make_values(100_000), 100_000}
  },
  formatters: [
    Benchee.Formatters.Console
  ],
  save: %{
    path: "bench/results/queue/runs/drop"
  },
  time: 1
)
