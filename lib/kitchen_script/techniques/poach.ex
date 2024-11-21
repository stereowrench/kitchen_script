defprotocol KitchenScript.Techniques.Poach do
  @spec recipe(t) :: KitchenScript.Recipe.t()
  def recipe(t)
end
