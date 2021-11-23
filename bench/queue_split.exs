defmodule BenchQueue do
  def make_queue(size) do
    1..size
    |> Enum.reduce(:queue.new(), fn i, queue ->
      :queue.in(i, queue)
    end)
  end

  def split(queue, amount) do
    {queue, rev_list} = do_split_rev(queue, amount, [])
    {queue, Enum.reverse(rev_list)}
  end

  def split_erlang(queue, amount) do
    {split, queue} = :queue.split(amount, queue)
    {queue, :queue.to_list(split)}
  end

  defp pop(queue) do
    case :queue.out(queue) do
      {{:value, value}, queue} ->
        {:ok, queue, value}

      {:empty, _queue} ->
        {:error, :empty}
    end
  end

  defp do_split_rev(queue, 0, list) do
    {queue, list}
  end

  defp do_split_rev(queue, amount, list) do
    case pop(queue) do
      {:ok, queue, value} ->
        do_split_rev(queue, amount - 1, [value | list])

      {:error, :empty} ->
        {queue, list}
    end
  end
end

queue = BenchQueue.make_queue(10)
{split_queue, split_result} = BenchQueue.split(queue, 5)
{split_erlang_queue, split_erlang_result} = BenchQueue.split_erlang(queue, 5)

if :queue.to_list(split_queue) != :queue.to_list(split_erlang_queue) do
  IO.puts("original queue: #{inspect(:queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the resulting queues of different split implementations are not the same:

  #{inspect(split_queue, charlists: :as_lists)} != #{
    inspect(split_erlang_queue, charlists: :as_lists)
  }
  """
end

if split_result != split_erlang_result do
  IO.puts("original queue: #{inspect(:queue.to_list(queue), charlists: :as_lists)}")

  raise """
  the results of different split implementations are not the same:

  #{inspect(split_result, charlists: :as_lists)} != #{
    inspect(split_erlang_result, charlists: :as_lists)
  }
  """
end

Benchee.run(
  %{
    "Split with erlang queue split and to_list" => fn {queue, amount} ->
      BenchQueue.split_erlang(queue, amount)
    end,
    "split using recursive elixir and Enum.reverse" => fn {queue, amount} ->
      BenchQueue.split(queue, amount)
    end
  },
  inputs: %{
    "queue size 10, split 1" => {BenchQueue.make_queue(10), 1},
    "queue size 10, split 10" => {BenchQueue.make_queue(10), 10},
    "queue size 1_000, split 1" => {BenchQueue.make_queue(1000), 1},
    "queue size 1_000, split 500" => {BenchQueue.make_queue(1000), 500},
    "queue size 1_000, split 1_000" => {BenchQueue.make_queue(1000), 1000},
    "queue size 100_000, split 1" => {BenchQueue.make_queue(100_000), 1},
    "queue size 100_000, split 5_000" => {BenchQueue.make_queue(100_000), 5000},
    "queue size 100_000, split 50_000" => {BenchQueue.make_queue(100_000), 50000},
    "queue size 100_000, split 100_000" => {BenchQueue.make_queue(100_000), 100_000}
  },
  formatters: [
    Benchee.Formatters.Console
  ],
  save: %{
    path: "bench/results/queue/runs"
  },
  time: 1
)
