defmodule KitchenScript.Ingredients.Eggs do
  defstruct []
end

defimpl Kitchen.Techniques.Poach, for: Kitchen.Ingredients.Eggs do
  alias Kitchen.Recipe
  require Recipe

  def recipe(_egg) do
    Recipe.recipe "poached egg" do
      makes(1)
      servings(0.5)

      ingredients do
        source(ingredient(:eggs, "eggs", {1, :each}))
        make(ingredient(:eggs2, "eggs", {1, :each}))
      end

      steps do
        step("""
        Bring pot to a simmer.
        """)

        step("""
        Gently place <%= @eggs %> into the water.
        """)

        step("""
        Cook for 4 minutes.
        """)
      end
    end
  end
end
