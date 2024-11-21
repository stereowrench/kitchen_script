defmodule KitchenScriptTest do
  alias KitchenScript.RecipeUnits
  use ExUnit.Case
  doctest KitchenScript

  test "unit conversion" do
    alias RecipeUnits

    assert {1, :tsp} = RecipeUnits.scale_up({1, :tsp})
    assert {1.0, :tbsp} = RecipeUnits.scale_up({3, :tsp})
    assert {1.0, :fl_oz} = RecipeUnits.scale_up({6, :tsp})
    assert {1.0, :cup} = RecipeUnits.scale_up({48, :tsp})
    assert {1.0, :pint} = RecipeUnits.scale_up({96, :tsp})
    assert {1.0, :quart} = RecipeUnits.scale_up({192, :tsp})
    assert {1.0, :gallon} = RecipeUnits.scale_up({768, :tsp})
  end
end
