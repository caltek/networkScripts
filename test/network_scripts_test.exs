defmodule NetworkScriptsTest do
  use ExUnit.Case
  doctest NetworkScripts

  test "greets the world" do
    assert NetworkScripts.hello() == :world
  end
end
