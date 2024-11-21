defmodule KitchenScriptTest do
  use ExUnit.Case
  doctest KitchenScript

  test "greets the world" do
    assert KitchenScript.hello() == :world
  end
end
