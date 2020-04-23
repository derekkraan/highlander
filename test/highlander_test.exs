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
