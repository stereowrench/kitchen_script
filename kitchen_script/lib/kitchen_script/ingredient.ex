defmodule KitchenScript.Ingredient do
  defstruct [:label, :ingredient, :qty, :recipe]

  @callback name() :: String.t()
end
