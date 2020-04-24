defmodule NetsplitTest do
  use ExUnit.Case

  test "runs a process on the cluster" do
    nodes = LocalCluster.start_nodes(:runs_process, 2)

    test_pid = self()

    for n <- nodes do
      {:ok, _} =
        rpc(n, Supervisor, :start_link, [
          [{Highlander, {TestProc, test_pid}}],
          [strategy: :one_for_one]
        ])
    end

    assert_receive({:hello_from, _})
    refute_receive({:hello_from, _})
  end

  test "heals after a netsplit" do
    nodes = LocalCluster.start_nodes(:netsplit, 2)

    test_pid = self()

    for n <- nodes do
      {:ok, _} =
        rpc(n, Supervisor, :start_link, [
          [{Highlander, {TestProc, test_pid}}],
          [strategy: :one_for_one]
        ])
    end

    Schism.partition([hd(nodes)])

    assert_receive({:hello_from, pid1})
    assert_receive({:hello_from, pid2})

    assert pid1 != pid2

    Schism.heal(nodes)

    assert_receive({:goodbye_from, losing_pid}, 1500)
    refute_receive({:goodbye_from, _winning_pid}, 500)

    pids_alive =
      [pid1, pid2]
      |> Enum.map(fn pid ->
        rpc(node(pid), Process, :alive?, [pid])
      end)
      |> Enum.frequencies()

    assert %{true: 1} = pids_alive
  end

  test "heals after a large netsplit" do
    nodes = LocalCluster.start_nodes(:netsplit_large, 10)

    test_pid = self()

    for n <- nodes do
      {:ok, _} =
        rpc(n, Supervisor, :start_link, [
          [{Highlander, {TestProc, test_pid}}],
          [strategy: :one_for_one]
        ])
    end

    Schism.partition(Enum.take(nodes, 4))

    assert_receive({:hello_from, pid1})
    assert_receive({:hello_from, pid2})
    refute_receive({:hello_from, _})
    pids = [pid1, pid2]

    assert pid1 != pid2

    Schism.heal(nodes)

    assert_receive({:goodbye_from, losing_pid}, 1500)
    refute_receive({:goodbye_from, _winning_pid}, 500)

    pids_alive =
      pids
      |> Enum.map(fn pid ->
        rpc(node(pid), Process, :alive?, [pid])
      end)
      |> Enum.frequencies()

    assert %{true: 1} = pids_alive
  end

  defp rpc(node, m, f, a) do
    :rpc.block_call(node, m, f, a)
  end
end
