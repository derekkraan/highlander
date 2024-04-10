defmodule Highlander do
  @external_resource "README.md"
  @moduledoc @external_resource
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  use GenServer
  require Logger

  def child_spec(child_child_spec) do
    child_child_spec = Supervisor.child_spec(child_child_spec, [])

    Logger.debug("Starting Highlander with #{inspect(child_child_spec.id)} as uniqueness key")

    %{
      id: child_child_spec.id,
      start: {GenServer, :start_link, [__MODULE__, child_child_spec, []]}
    }
  end

  @impl true
  def init(child_spec) do
    Process.flag(:trap_exit, true)
    {:ok, register(%{child_spec: child_spec})}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _}, %{ref: ref} = state) do
    {:noreply, register(state)}
  end

  def handle_info({:EXIT, _pid, :name_conflict}, %{pid: pid} = state) do
    :ok = Supervisor.stop(pid, :shutdown)
    {:stop, {:shutdown, :name_conflict}, Map.delete(state, :pid)}
  end

  @impl true
  def terminate(reason, %{pid: pid}) do
    :ok = Supervisor.stop(pid, reason)
  end

  def terminate(_, _), do: nil

  defp name(%{child_spec: %{id: global_name}}) do
    {__MODULE__, global_name}
  end

  defp handle_conflict(_name, pid1, pid2) do
    Process.exit(pid2, :name_conflict)
    pid1
  end

  defp register(state) do
    case :global.register_name(name(state), self(), &handle_conflict/3) do
      :yes -> start(state)
      :no -> monitor(state)
    end
  end

  defp start(state) do
    {:ok, pid} = Supervisor.start_link([state.child_spec], strategy: :one_for_one)
    Map.put(state, :pid, pid)
  end

  defp monitor(state) do
    case :global.whereis_name(name(state)) do
      :undefined ->
        register(state)

      pid ->
        ref = Process.monitor(pid)
        %{child_spec: state.child_spec, ref: ref}
    end
  end
end
