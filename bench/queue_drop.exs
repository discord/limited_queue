defmodule BenchQueue do
  def make_queue(size) do
    1..size
    |> Enum.reduce(:queue.new(), fn i, queue ->
      :queue.in(i, queue)
    end)
  end

  def drop_split(queue, amount) do
    {_dropped_split, queue} = :queue.split(amount, queue)
    queue
  end

  def drop_reduce(queue, amount) do
    Enum.reduce(1..amount, queue, fn _, queue -> :queue.drop(queue) end)
  end
end

queue = BenchQueue.make_queue(10)
drop_split_queue = BenchQueue.drop_split(queue, 5)
drop_reduce_queue = BenchQueue.drop_reduce(queue, 5)

if :queue.to_list(drop_split_queue) != :queue.to_list(drop_reduce_queue) do
  IO.puts("original queue: #{inspect(:queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the resulting queues of different drop implementations are not the same:

  #{inspect(drop_split_queue, charlists: :as_lists)} != #{
    inspect(drop_reduce_queue, charlists: :as_lists)
  }
  """
end

Benchee.run(
  %{
    "Drop with erlang queue split" => fn {queue, amount} ->
      BenchQueue.drop_split(queue, amount)
    end,
    "Drop with recursive erlang queue drop" => fn {queue, amount} ->
      BenchQueue.drop_reduce(queue, amount)
    end
  },
  inputs: %{
    "queue size 10, drop 1" => {BenchQueue.make_queue(10), 1},
    "queue size 10, drop 10" => {BenchQueue.make_queue(10), 10},
    "queue size 1_000, drop 1" => {BenchQueue.make_queue(1000), 1},
    "queue size 1_000, drop 500" => {BenchQueue.make_queue(1000), 500},
    "queue size 1_000, drop 1_000" => {BenchQueue.make_queue(1000), 1000},
    "queue size 100_000, drop 1" => {BenchQueue.make_queue(100_000), 1},
    "queue size 100_000, drop 5_000" => {BenchQueue.make_queue(100_000), 5000},
    "queue size 100_000, drop 50_000" => {BenchQueue.make_queue(100_000), 50000},
    "queue size 100_000, drop 100_000" => {BenchQueue.make_queue(100_000), 100_000}
  },
  formatters: [
    Benchee.Formatters.Console
  ],
  save: %{
    path: "bench/results/queue/runs/drop"
  },
  time: 1
)
