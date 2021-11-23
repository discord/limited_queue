# limited_queue

[![CI](https://github.com/discord/limited_queue/actions/workflows/ci.yml/badge.svg)](https://github.com/discord/limited_queue/actions/workflows/ci.yml)
[![Hex.pm Version](http://img.shields.io/hexpm/v/limited_queue.svg?style=flat)](https://hex.pm/packages/limited_queue)
[![Hex.pm License](http://img.shields.io/hexpm/l/limited_queue.svg?style=flat)](https://hex.pm/packages/limited_queue)
[![HexDocs](https://img.shields.io/badge/HexDocs-Yes-blue)](https://hexdocs.pm/limited_queue)

`limited_queue` is a simple Elixir queue, with a constant-time `size/1` and a maximum capacity.

## Usage

Add it to `mix.exs`

```elixir
defp deps do
  [{:limited_queue, "~> 0.1.0"}]
end
```

Create a new queue with a capacity and drop strategy, then push and pop values from it.

```elixir
queue = 
  LimitedQueue.new(2, :drop_newest)
  |> LimitedQueue.push("a")
  |> LimitedQueue.push("b")
  |> LimitedQueue.push("c")

{:ok, queue, "a"} = LimitedQueue.pop(queue)
{:ok, queue, "b"} = LimitedQueue.pop(queue)
{:error, :empty} = LimitedQueue.pop(queue)
0 = LimitedQueue.size(queue)
2 = LimitedQueue.capacity(queue)
```

You can also `append/2` multiple values to a queue at once, and get information about how many were dropped.

```elixir
queue = LimitedQueue.new(2, :drop_newest)

{queue, dropped} = LimitedQueue.append(queue, ["a", "b", "c"])
1 = dropped
2 = LimitedQueue.size(queue)

{:ok, queue, "a"} = LimitedQueue.pop(queue)
{:ok, queue, "b"} = LimitedQueue.pop(queue)
{:error, :empty} = LimitedQueue.pop(queue)
```

`split/2` allows getting multiple values from the queue at once.

```elixir
queue = LimitedQueue.new(10, :drop_newest)

{queue, 0} = LimitedQueue.append(queue, ["a", "b", "c"])

{queue, values} = LimitedQueue.split(queue, 2)
["a", "b"] = values
1 = LimitedQueue.size(queue)
```

## Documentation

This library contains internal documentation.
Documentation is available on [HexDocs](https://hexdocs.pm/limited_queue), 
or you can generate the documentation from source:

```bash
$ mix deps.get
$ mix docs
```

## Running the Tests

Tests can be run by running `mix test` in the root directory of the library.

## Compared to `deque`

`LimitedQueue` has similar performance to [deque](https://hex.pm/packages/deque) depending on the situation (see Benchmarks).
It has a more special-purpose limited interface, it is a single-sided queue, and its internals are built on Erlang's `:queue`.

## Performance and Benchmarking

Benchmarks can be run by running `mix run bench/<benchmark file>.exs` in the root directory of the library.

## License

`LimitedQueue` is released under [the MIT License](LICENSE).
Check [LICENSE](LICENSE) file for more information.
