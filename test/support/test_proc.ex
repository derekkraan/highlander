defmodule TestProc do
  use GenServer
  require Logger

  def child_spec(test_pid) do
    %{id: 1, start: {GenServer, :start_link, [__MODULE__, test_pid, []]}}
  end

  def init(test_pid) do
    Process.flag(:trap_exit, true)
    send(test_pid, {:hello_from, self()})
    {:ok, test_pid}
  end

  def terminate(_, test_pid) do
    send(test_pid, {:goodbye_from, self()})
  end
end
