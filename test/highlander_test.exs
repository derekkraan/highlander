defmodule HighlanderTest do
  use ExUnit.Case
  doctest Highlander

  test "runs two processes" do
    test_pid = self()

    child_spec = %{
      start:
        {Task, :start_link,
         [
           fn ->
             send(test_pid, :hello)
             Process.sleep(1000)
           end
         ]},
      restart: :transient
    }

    Supervisor.start_link(
      [
        {Highlander, Map.put(child_spec, :id, :one)},
        {Highlander, Map.put(child_spec, :id, :two)}
      ],
      strategy: :one_for_one
    )

    assert_receive(:hello)
    assert_receive(:hello)
  end

  test "runs only one process" do
    test_pid = self()

    child_spec = %{
      start:
        {Task, :start_link,
         [
           fn ->
             send(test_pid, :hello)
             Process.sleep(1000)
           end
         ]},
      restart: :transient
    }

    Supervisor.start_link(
      [
        {Highlander, Map.put(child_spec, :id, :one)}
      ],
      strategy: :one_for_one
    )

    Supervisor.start_link(
      [
        {Highlander, Map.put(child_spec, :id, :one)}
      ],
      strategy: :one_for_one
    )

    assert_receive(:hello)
    refute_receive(:hello)
  end

  test "takes over when one process dies" do
    test_pid = self()

    child_spec = %{
      start:
        {Task, :start_link,
         [
           fn ->
             send(test_pid, :hello)
             Process.sleep(1000)
           end
         ]},
      restart: :transient
    }

    {:ok, pid1} =
      Supervisor.start_link(
        [
          {Highlander, Map.put(child_spec, :id, :one)}
        ],
        strategy: :one_for_one
      )

    {:ok, pid2} =
      Supervisor.start_link(
        [
          {Highlander, Map.put(child_spec, :id, :one)}
        ],
        strategy: :one_for_one
      )

    assert_receive(:hello)
    refute_receive(:hello)

    Supervisor.stop(pid1)

    assert_receive(:hello)
    refute_receive(:hello)
  end

  test "accepts {module, arg} child_child_spec" do
    test_pid = self()

    Supervisor.start_link(
      [
        {Highlander,
         {Task,
          fn ->
            send(test_pid, :hello)
            Process.sleep(1000)
          end}}
      ],
      strategy: :one_for_one
    )

    assert_receive(:hello)
  end

  defmodule TestServer do
    use GenServer

    def start_link(any), do: GenServer.start_link(__MODULE__, any)
    def init(_), do: {:ok, nil}
    def handle_call(:who_are_you, _, state), do: {:reply, __MODULE__, state}
  end

  test "handle_call(:get_pid, _, _) returns child process pid" do
    test_pid = self()
    key = {Highlander, HighlanderTest.TestServer}
    Supervisor.start_link([key], strategy: :one_for_one)

    supervisor_pid = :global.whereis_name(key)
    pid = GenServer.call(supervisor_pid, :get_pid)
    assert HighlanderTest.TestServer == GenServer.call(pid, :who_are_you)
  end
end
