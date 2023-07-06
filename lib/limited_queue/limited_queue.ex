defmodule LimitedQueue do
  @moduledoc """
  An elixir wrapper for erlang's `:queue`, with a constant-time `size/1` and a maximum capacity.

  When items pushed on to the `LimitedQueue` put it over its maximum capacity,
  it will drop events according to its `drop_strategy/0`.
  """

  @typedoc """
  The opaque internal state of the `LimitedQueue`.
  """
  @opaque t(value) :: %__MODULE__{
            queue: :queue.queue(value),
            size: non_neg_integer(),
            capacity: pos_integer(),
            drop_strategy: drop_strategy()
          }

  @typedoc """
  The `drop_strategy/0` determines how the queue handles dropping events when overloaded.

  `:drop_newest` (default) drops incoming events and is the most efficient
    because it will avoid touching the state when the queue is overloaded.

  `:drop_oldest` drops the oldest events from the queue,
    which may be better behavior where newer events are more relevant to process than older ones.
  """
  @type drop_strategy :: :drop_newest | :drop_oldest

  @enforce_keys [:queue, :size, :capacity, :drop_strategy]
  defstruct [:queue, :size, :capacity, :drop_strategy]

  @doc """
  Create a new `LimitedQueue` with the given maximum capacity.

  The `drop_strategy` determines how the queue handles dropping events when overloaded.
  See `drop_strategy/0` for more information.
  """
  @spec new(capacity :: pos_integer()) :: t(value) when value: any()
  @spec new(capacity :: pos_integer(), drop_strategy()) :: t(value) when value: any()
  def new(capacity, drop_strategy \\ :drop_newest)
      when capacity > 0 and drop_strategy in [:drop_newest, :drop_oldest] do
    %__MODULE__{queue: :queue.new(), size: 0, capacity: capacity, drop_strategy: drop_strategy}
  end

  @doc """
  Push a value to the back of the `LimitedQueue`.

  If the `LimitedQueue` is full, it will drop an event according to the `LimitedQueue`'s `drop_strategy/0`.
  """
  @spec push(t(value), value) :: t(value) when value: any()
  def push(
        %__MODULE__{capacity: capacity, size: capacity, drop_strategy: :drop_newest} = state,
        _element
      ) do
    state
  end

  def push(
        %__MODULE__{capacity: capacity, size: capacity, drop_strategy: :drop_oldest} = state,
        element
      ) do
    queue = :queue.drop(state.queue)
    queue = :queue.in(element, queue)
    %__MODULE__{state | queue: queue}
  end

  def push(%__MODULE__{} = state, element) do
    queue = :queue.in(element, state.queue)

    %__MODULE__{
      state
      | queue: queue,
        size: state.size + 1
    }
  end

  @doc """
  Push multiple values to the back of the `LimitedQueue`.

  Returns the number of values that were dropped if the `LimitedQueue` reaches its capacity.
  """
  @spec append(t(value), [value]) :: {t(value), dropped :: non_neg_integer()} when value: any()
  def append(
        %__MODULE__{capacity: capacity, size: capacity, drop_strategy: :drop_newest} = state,
        events
      ) do
    {state, length(events)}
  end

  def append(%__MODULE__{capacity: capacity, size: capacity} = state, [event]) do
    state = push(state, event)
    {state, 1}
  end

  def append(%__MODULE__{} = state, [event]) do
    state = push(state, event)
    {state, 0}
  end

  def append(%__MODULE__{} = state, events) do
    Enum.reduce(events, {state, 0}, fn value, {state, dropped} ->
      dropped =
        if state.size == state.capacity do
          dropped + 1
        else
          dropped
        end

      state = push(state, value)
      {state, dropped}
    end)
  end

  @doc """
  Remove and return a value from the front of the `LimitedQueue`.
  If the `LimitedQueue` is empty, {:error, :empty} will be returned.
  """
  @spec pop(t(value)) :: {:ok, t(value), value} | {:error, :empty} when value: any()
  def pop(%__MODULE__{} = state) do
    case :queue.out(state.queue) do
      {{:value, value}, queue} ->
        state = %__MODULE__{
          state
          | queue: queue,
            size: state.size - 1
        }

        {:ok, state, value}

      {:empty, _queue} ->
        {:error, :empty}
    end
  end

  @doc """
  Remove and return multiple values from the front of the `LimitedQueue`.
  If the `LimitedQueue` runs out of values, fewer values than the requested amount will be returned.
  """
  @spec split(t(value), amount :: non_neg_integer()) :: {t(value), [value]} when value: any()
  def split(%__MODULE__{size: 0} = state, amount) when amount >= 0 do
    {state, []}
  end

  def split(%__MODULE__{size: size} = state, amount) when amount >= size do
    split = state.queue
    state = %__MODULE__{state | queue: :queue.new(), size: 0}
    {state, :queue.to_list(split)}
  end

  def split(%__MODULE__{} = state, amount) when amount > 0 do
    {split, queue} = :queue.split(amount, state.queue)
    state = %__MODULE__{state | queue: queue, size: state.size - amount}
    {state, :queue.to_list(split)}
  end

  def split(%__MODULE__{} = state, 0) do
    {state, []}
  end

  @doc """
  Filters the queue, i.e. returns only those elements for which fun returns a truthy value.
  """
  @spec filter(t(value), (value -> boolean)) :: t(value) when value: any()
  def filter(%__MODULE__{} = state, fun) do
    queue = :queue.filter(fun, state.queue)
    %__MODULE__{state | queue: queue, size: :queue.len(queue)}
  end

  @doc """
  The current number of values stored in the `LimitedQueue`.
  """
  @spec size(t(value)) :: non_neg_integer() when value: any()
  def size(%__MODULE__{} = state) do
    state.size
  end

  @doc """
  The maximum capacity of the `LimitedQueue`.
  """
  @spec capacity(t(value)) :: non_neg_integer() when value: any()
  def capacity(%__MODULE__{} = state) do
    state.capacity
  end

  @doc """
  The contents of the `LimitedQueue` as a list.
  """
  @spec to_list(t(value)) :: [value] when value: any()
  def to_list(%__MODULE__{} = state) do
    :queue.to_list(state.queue)
  end
end
