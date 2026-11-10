defmodule HighlanderTest do
  use ExUnit.Case
  doctest Highlander

  @moduletag :capture_log

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

    {:ok, _pid2} =
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

  test "does not crash on a name conflict exit signal when it never became the owner" do
    global_name = :non_owner_name_conflict

    # Simulate another node/process already owning the global name
    fake_owner = spawn(fn -> Process.sleep(:infinity) end)
    :yes = :global.register_name({Highlander, global_name}, fake_owner)

    child_spec = %{
      id: global_name,
      start: {Task, :start_link, [fn -> Process.sleep(:infinity) end]}
    }

    # Start a Highlander process that will monitor our fake_owner above.
    {:ok, pid} = GenServer.start_link(Highlander, child_spec)

    # Use this as the sender of the EXIT below, not the test process. The test
    # process is the GenServer's parent, and OTP handles an EXIT from the parent
    # itself instead of passing it to `handle_info`.
    unrelated_pid = spawn(fn -> Process.sleep(:infinity) end)

    # Verify the monitoring process was set up correctly and does not have a
    # `:pid` in its state.
    refute Map.has_key?(:sys.get_state(pid), :pid)

    send(pid, {:EXIT, unrelated_pid, :name_conflict})

    assert :sys.get_state(pid) |> is_map()
    assert Process.alive?(pid)

    :global.unregister_name(global_name)
    Process.exit(fake_owner, :kill)
  end

  test "owner recovers in place (does not get restarted) when it loses a name_conflict" do
    Process.flag(:trap_exit, true)
    test_pid = self()
    global_name = :owner_recovers_in_place

    child_spec = %{
      id: global_name,
      start:
        {Task, :start_link,
         [
           fn ->
             send(test_pid, :hello)
             Process.sleep(:infinity)
           end
         ]}
    }

    # Run the owner under a real, default (:permanent) supervisor
    {:ok, sup} = Supervisor.start_link([{Highlander, child_spec}], strategy: :one_for_one)
    [{_, owner, _, _}] = Supervisor.which_children(sup)
    assert_receive(:hello)
    assert %{pid: local_supervisor} = :sys.get_state(owner)
    [{_, singleton, _, _}] = Supervisor.which_children(local_supervisor)

    # We can use `self()` as the sender here because the owner's parent is
    # `sup`, not the test process. OTP only handles an EXIT specially when it
    # comes from the parent.
    send(owner, {:EXIT, self(), :name_conflict})
    Process.sleep(50)

    refute Process.alive?(local_supervisor), "local supervisor should have been stopped"
    refute Process.alive?(singleton), "the singleton should have been stopped"

    # The critical assertion: this must be the *same* pid. Previously the
    # owner clause called `{:stop, {:shutdown, :name_conflict}, state}`,
    # which caused its `:permanent` parent supervisor to restart it here.
    # Under real production load (multiple singletons all losing a conflict
    # at the same instant on every node join), enough simultaneous restarts
    # exceeded the supervisor's restart intensity and took the whole
    # supervisor - and the entire BEAM node - down with it.
    [{_, owner_after, _, _}] = Supervisor.which_children(sup)

    assert owner == owner_after,
           "owner should recover in place, not be restarted by its supervisor"

    state_after = :sys.get_state(owner)
    refute Map.has_key?(state_after, :pid), "owner should have transitioned to monitor state"
    assert Map.has_key?(state_after, :ref)
  end

  test "crashes (so it can be restarted) when its local supervisor dies on its own" do
    Process.flag(:trap_exit, true)
    test_pid = self()
    global_name = :owner_local_supervisor_dies

    child_spec = %{
      id: global_name,
      start:
        {Task, :start_link,
         [
           fn ->
             send(test_pid, :hello)
             Process.sleep(:infinity)
           end
         ]}
    }

    {:ok, owner} = GenServer.start_link(Highlander, child_spec)
    assert_receive(:hello)
    %{pid: local_supervisor} = :sys.get_state(owner)

    ref = Process.monitor(owner)

    # A local supervisor exceeding its restart intensity exits with
    # `:shutdown`. This must not be swallowed: if it were, the owner would
    # stay alive holding the global name with a dead supervisor and nothing
    # running anywhere in the cluster.
    :ok = :sys.terminate(local_supervisor, :shutdown)

    assert_receive({:DOWN, ^ref, :process, ^owner, _reason}, 500)
    assert :global.whereis_name({Highlander, global_name}) == :undefined
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
end
