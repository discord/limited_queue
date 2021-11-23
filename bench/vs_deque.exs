defmodule BenchQueueVsDeque do
  alias LimitedQueue
  alias Deque

  def make_queues(capacity) do
    queue_drop_old = LimitedQueue.new(capacity, :drop_oldest)
    queue_drop_new = LimitedQueue.new(capacity, :drop_newest)
    deque = Deque.new(capacity)
    {queue_drop_old, queue_drop_new, deque}
  end

  def make_full_queues(capacity) do
    {queue_drop_old, queue_drop_new, deque} = make_queues(capacity)

    values = make_values(capacity)
    {queue_drop_old, 0} = LimitedQueue.append(queue_drop_old, values)
    {queue_drop_new, 0} = LimitedQueue.append(queue_drop_new, values)
    deque = Enum.reduce(values, deque, &Deque.append(&2, &1))

    {queue_drop_old, queue_drop_new, deque}
  end

  def make_values(amount) do
    List.duplicate(:test, amount)
  end
end

# mac can't measure nanoseconds, so make sure the tests run long enough to measure accurately
# see this benchee issue: https://github.com/bencheeorg/benchee/issues/313
run_multiplier = 1000

push_tests = %{
  "Push to Queue (drop oldest)" => fn {{queue_drop_old, _queue_drop_new, _deque}, values} ->
    for _ <- 1..run_multiplier do
      Enum.reduce(values, {queue_drop_old, 0}, fn value, {queue, dropped} ->
        dropped =
          if LimitedQueue.size(queue) == LimitedQueue.capacity(queue) do
            dropped + 1
          else
            dropped
          end

        queue = LimitedQueue.push(queue, value)
        {queue, dropped}
      end)
    end
  end,
  "Push to Deque" => fn {{_queue_drop_old, _queue_drop_new, deque}, values} ->
    for _ <- 1..run_multiplier do
      Enum.reduce(values, {deque, 0}, fn value, {deque, dropped} ->
        count = Enum.count(deque)
        deque = Deque.append(deque, value)

        if count == Enum.count(deque) do
          {deque, dropped + 1}
        else
          {deque, dropped}
        end
      end)
    end
  end,
  "Append to Queue (drop oldest)" => fn {{queue_drop_old, _queue_drop_new, _deque}, values} ->
    for _ <- 1..run_multiplier do
      LimitedQueue.append(queue_drop_old, values)
    end
  end
}

pop_tests = %{
  "Pop from Queue (drop oldest)" => fn {{queue_drop_old, _queue_drop_new, _deque}, count} ->
    for _ <- 1..run_multiplier do
      Enum.reduce(1..count, {queue_drop_old, []}, fn _, {queue, values} ->
        {:ok, queue, value} = LimitedQueue.pop(queue)
        {queue, [value | values]}
      end)
    end
  end,
  "Pop from Deque" => fn {{_queue_drop_old, _queue_drop_new, deque}, count} ->
    for _ <- 1..run_multiplier do
      Enum.reduce(1..count, {deque, []}, fn _, {deque, values} ->
        {value, deque} = Deque.pop(deque)
        {deque, [value | values]}
      end)
    end
  end,
  "Split from Queue (drop oldest)" => fn {{queue_drop_old, _queue_drop_new, _deque}, count} ->
    for _ <- 1..run_multiplier do
      {_queue, _values} = LimitedQueue.split(queue_drop_old, count)
    end
  end
}

real_world_tests = %{
  "Append and pop from Queue (drop oldest)" => fn {{queue_drop_old, _queue_drop_new, _deque},
                                                   values, push_batch_size, pop_batch_size} ->
    push_chunks = Enum.chunk_every(values, push_batch_size)
    pop_chunks = Enum.chunk_every(values, pop_batch_size)

    Enum.reduce(1..100, queue_drop_old, fn _run, queue ->
      queue =
        Enum.reduce(push_chunks, queue, fn chunk, queue ->
          {queue, 0} = LimitedQueue.append(queue, chunk)
          queue
        end)

      Enum.reduce(pop_chunks, queue, fn _chunk, queue ->
        {queue, _batch_values} = LimitedQueue.split(queue, pop_batch_size)
        queue
      end)
    end)
  end,
  "Append and pop from Deque" => fn {{_queue_drop_old, _queue_drop_new, deque}, values,
                                     push_batch_size, pop_batch_size} ->
    push_chunks = Enum.chunk_every(values, push_batch_size)
    pop_chunks = Enum.chunk_every(values, pop_batch_size)

    Enum.reduce(1..100, deque, fn _run, deque ->
      deque =
        Enum.reduce(push_chunks, deque, fn chunk, deque ->
          Enum.reduce(chunk, deque, &Deque.append(&2, &1))
        end)

      Enum.reduce(pop_chunks, deque, fn _chunk, deque ->
        {deque, _batch_values} =
          Enum.reduce_while(1..pop_batch_size, {deque, []}, fn _, {deque, batch_values} ->
            {value, deque} = Deque.pop(deque)

            if value == nil do
              {:halt, {deque, batch_values}}
            else
              {:cont, {deque, [value | batch_values]}}
            end
          end)

        deque
      end)
    end)
  end
}

Benchee.run(
  push_tests,
  inputs: %{
    "empty size 10, values 1" =>
      {BenchQueueVsDeque.make_queues(10), BenchQueueVsDeque.make_values(1)},
    "empty size 10, values 10" =>
      {BenchQueueVsDeque.make_queues(10), BenchQueueVsDeque.make_values(10)},
    "empty size 1_000, values 1" =>
      {BenchQueueVsDeque.make_queues(1_000), BenchQueueVsDeque.make_values(1)},
    "empty size 1_000, values 10" =>
      {BenchQueueVsDeque.make_queues(1_000), BenchQueueVsDeque.make_values(10)},
    "empty size 1_000_000, values 1" =>
      {BenchQueueVsDeque.make_queues(1_000_000), BenchQueueVsDeque.make_values(1)},
    "empty size 1_000_000, values 10" =>
      {BenchQueueVsDeque.make_queues(1_000_000), BenchQueueVsDeque.make_values(10)},
    "empty size 1_000_000, values 1_000" =>
      {BenchQueueVsDeque.make_queues(1_000_000), BenchQueueVsDeque.make_values(1_000)}
  },
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/results/queue/html/empty-push.html"}
  ],
  save: %{
    path: "bench/results/queue/runs/empty-push"
  },
  time: 5
)

Benchee.run(
  push_tests,
  inputs: %{
    "full size 10, values 1" =>
      {BenchQueueVsDeque.make_full_queues(10), BenchQueueVsDeque.make_values(1)},
    "full size 10_000, values 1" =>
      {BenchQueueVsDeque.make_full_queues(10_000), BenchQueueVsDeque.make_values(1)},
    "full size 10_000, values 10" =>
      {BenchQueueVsDeque.make_full_queues(10_000), BenchQueueVsDeque.make_values(10)},
    "full size 10_000, values 1_000" =>
      {BenchQueueVsDeque.make_full_queues(10_000), BenchQueueVsDeque.make_values(1_000)}
  },
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/results/queue/html/full-push.html"}
  ],
  save: %{
    path: "bench/results/queue/runs/full-push"
  },
  time: 5
)

Benchee.run(
  pop_tests,
  inputs: %{
    "full size 10, count 1" => {BenchQueueVsDeque.make_full_queues(10), 1},
    "full size 10_000, count 1" => {BenchQueueVsDeque.make_full_queues(10_000), 1},
    "full size 10_000, count 100" => {BenchQueueVsDeque.make_full_queues(10_000), 100},
    "full size 100_000, count 1_000" => {BenchQueueVsDeque.make_full_queues(100_000), 1_000}
  },
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/results/queue/html/full-push.html"}
  ],
  save: %{
    path: "bench/results/queue/runs/full-push"
  },
  time: 5
)

Benchee.run(
  real_world_tests,
  inputs: %{
    "push batch 1, pop batch 10" =>
      {BenchQueueVsDeque.make_queues(10_000), BenchQueueVsDeque.make_values(1_000), 1, 10},
    "push batch 1, pop batch 100" =>
      {BenchQueueVsDeque.make_queues(10_000), BenchQueueVsDeque.make_values(1_000), 1, 100},
    "push batch 2, pop batch 100" =>
      {BenchQueueVsDeque.make_queues(10_000), BenchQueueVsDeque.make_values(1_000), 2, 100},
    "push batch 10, pop batch 100" =>
      {BenchQueueVsDeque.make_queues(10_000), BenchQueueVsDeque.make_values(1_000), 10, 100}
  },
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/results/queue/html/real-world-push.html"}
  ],
  save: %{
    path: "bench/results/queue/runs/real-world-push"
  },
  time: 5
)
