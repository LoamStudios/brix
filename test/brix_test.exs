defmodule BrixTest do
  use ExUnit.Case
  doctest Brix

  test "greets the world" do
    assert Brix.hello() == :world
  end
end
