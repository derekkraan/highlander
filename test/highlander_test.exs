defmodule HighlanderTest do
  use ExUnit.Case
  doctest Highlander

  test "greets the world" do
    assert Highlander.hello() == :world
  end
end
