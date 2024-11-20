defmodule RecipeExtractorTest do
  use ExUnit.Case
  doctest RecipeExtractor

  test "greets the world" do
    assert RecipeExtractor.hello() == :world
  end
end
