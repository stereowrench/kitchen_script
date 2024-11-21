defmodule KitchenScript.Ingredients.Onion do
  @behaviour KitchenScript.Ingredient

  @impl true
  def name do
    "Onion"
  end

  @impl true
  def min_qty() do
    {1 / 3, :tsp}
  end
end
