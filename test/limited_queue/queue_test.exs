defmodule LimitedQueue.QueueTest do
  @moduledoc false
  use ExUnit.Case

  alias LimitedQueue, as: Queue

  describe "queue with capacity" do
    test "queue can be created" do
      capacity = 10
      queue = Queue.new(capacity)
      assert Queue.capacity(queue) == capacity
      assert Queue.size(queue) == 0
    end

    test "queue can be pushed to" do
      queue = Queue.new(10)
      queue = Queue.push(queue, "a")
      assert Queue.size(queue) == 1
    end

    test "queue can get full" do
      queue = Queue.new(2)
      queue = Queue.push(queue, "a")
      queue = Queue.push(queue, "a")
      queue = Queue.push(queue, "a")
      assert Queue.size(queue) == 2
    end

    test "queue can have values popped" do
      queue = Queue.new(2)
      queue = Queue.push(queue, "a")
      {:ok, queue, "a"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue push is FIFO" do
      queue = Queue.new(2)
      queue = Queue.push(queue, "a")
      queue = Queue.push(queue, "b")
      {:ok, queue, "a"} = Queue.pop(queue)
      {:ok, queue, "b"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue can be appended to" do
      queue = Queue.new(5)
      {queue, 0} = Queue.append(queue, ["a", "b", "c"])
      assert Queue.size(queue) == 3
    end

    test "queue append is FIFO" do
      queue = Queue.new(4)
      {queue, 0} = Queue.append(queue, ["a", "b"])
      {queue, 0} = Queue.append(queue, ["c", "d"])
      {:ok, queue, "a"} = Queue.pop(queue)
      {:ok, queue, "b"} = Queue.pop(queue)
      {:ok, queue, "c"} = Queue.pop(queue)
      {:ok, queue, "d"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue push respects the capacity" do
      queue = Queue.new(2)
      {queue, 0} = Queue.append(queue, ["a", "b"])
      queue = Queue.push(queue, "a")
      assert Queue.size(queue) == 2
    end

    test "queue append respects the capacity" do
      queue = Queue.new(2)
      {queue, 1} = Queue.append(queue, ["a", "b", "c"])
      assert Queue.size(queue) == 2
    end

    test "queue append drops the newest elements with push when it reaches capacity in :drop_newest mode" do
      queue = Queue.new(2, :drop_newest)
      queue = Queue.push(queue, "a")
      queue = Queue.push(queue, "b")
      assert Queue.size(queue) == 2
      queue = Queue.push(queue, "c")
      assert Queue.size(queue) == 2
      {:ok, queue, "a"} = Queue.pop(queue)
      {:ok, queue, "b"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue append drops the newest elements with append when it reaches capacity in :drop_newest mode" do
      queue = Queue.new(2, :drop_newest)
      {queue, 1} = Queue.append(queue, ["a", "b", "c"])
      {:ok, queue, "a"} = Queue.pop(queue)
      {:ok, queue, "b"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue append drops the oldest elements with push when it reaches capacity in :drop_oldest mode" do
      queue = Queue.new(2, :drop_oldest)
      queue = Queue.push(queue, "a")
      assert Queue.size(queue) == 1
      queue = Queue.push(queue, "b")
      assert Queue.size(queue) == 2
      queue = Queue.push(queue, "c")
      assert Queue.size(queue) == 2
      {:ok, queue, "b"} = Queue.pop(queue)
      {:ok, queue, "c"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue append keeps all elements with append when it is below capacity in :drop_oldest mode" do
      queue = Queue.new(2, :drop_oldest)
      {queue, 0} = Queue.append(queue, ["a"])
      assert Queue.size(queue) == 1
      {:ok, queue, "a"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue append keeps all elements with append when it is equal to the capacity in :drop_oldest mode" do
      queue = Queue.new(2, :drop_oldest)
      {queue, 0} = Queue.append(queue, ["a", "b"])
      assert Queue.size(queue) == 2
      {:ok, queue, "a"} = Queue.pop(queue)
      {:ok, queue, "b"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue append drops the oldest elements with append when it goes over capacity in :drop_oldest mode" do
      queue = Queue.new(3, :drop_oldest)
      {queue, 0} = Queue.append(queue, ["a", "b"])
      assert Queue.size(queue) == 2
      {queue, 1} = Queue.append(queue, ["c", "d"])
      assert Queue.size(queue) == 3
      {:ok, queue, "b"} = Queue.pop(queue)
      {:ok, queue, "c"} = Queue.pop(queue)
      {:ok, queue, "d"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue append drops the oldest elements with append when more elements are added than its capacity in :drop_oldest mode" do
      queue = Queue.new(2, :drop_oldest)
      {queue, 1} = Queue.append(queue, ["a", "b", "c"])
      assert Queue.size(queue) == 2
      {:ok, queue, "b"} = Queue.pop(queue)
      {:ok, queue, "c"} = Queue.pop(queue)
      assert Queue.size(queue) == 0
    end

    test "queue that has reached capacity can accept more elements again after some have been popped" do
      queue = Queue.new(2)
      {queue, 0} = Queue.append(queue, ["a", "b"])
      queue = Queue.push(queue, "c")
      {:ok, queue, "a"} = Queue.pop(queue)
      {:ok, queue, "b"} = Queue.pop(queue)
      queue = Queue.push(queue, "c")
      assert Queue.size(queue) == 1
    end

    test "queue can be split" do
      queue = Queue.new(10)
      {queue, 0} = Queue.append(queue, ["a", "b", "c", "d"])
      {queue, values} = Queue.split(queue, 2)
      assert Queue.size(queue) == 2
      assert is_list(values)
      assert values == ["a", "b"]

      {queue, values} = Queue.split(queue, 2)
      assert Queue.size(queue) == 0
      assert is_list(values)
      assert values == ["c", "d"]
    end

    test "popping an empty queue returns an error" do
      queue = Queue.new(10)
      {:error, :empty} = Queue.pop(queue)

      queue = Queue.push(queue, "a")
      {:ok, queue, "a"} = Queue.pop(queue)
      {:error, :empty} = Queue.pop(queue)

      {queue, 0} = Queue.append(queue, ["a", "b"])
      {:ok, queue, "a"} = Queue.pop(queue)
      {:ok, queue, "b"} = Queue.pop(queue)
      {:error, :empty} = Queue.pop(queue)
    end

    test "queue can be viewed as a list" do
      queue = Queue.new(10)
      values = ["a", "b", "c"]
      {queue, 0} = Queue.append(queue, values)
      assert Queue.to_list(queue) == values
    end
  end
end
