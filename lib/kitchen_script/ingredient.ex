defmodule KitchenScript.Ingredient do
  defstruct [:label, :ingredient, :qty, :recipe, :module]

  @callback name() :: String.t()

  @callback min_qty() :: {number(), atom()}

  @optional_callbacks min_qty: 0
end
