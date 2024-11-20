defmodule MyRecipe do
  use Kitchen

  recipe "bar ingredient" do
    servings(2)
    makes({2, :cup})

    ingredients do
      source(ingredient(:baz, "baz", {1, :cup}))
    end

    steps do
      step("Whisk it")
    end
  end

  recipe "creme brulee" do
    servings(4)
    makes({1, :cup})

    ingredients do
      source(ingredient(:eggs, "eggs", {2, :each}))
      source(ingredient(:eggs_2, "eggs", {3, :each}))
      source(ingredient(:milk, "milk", {1, :cup}))
      make(ingredient(:foo, "bar ingredient", {1, :cup}))
    end

    steps do
      step("""
      Heat <%= @eggs %>
      """)
    end
  end

  make(1, "creme brulee")

  print_kitchen()
end

# defmodule Thing do
#   def bar() do
#     egg = %Kitchen.Ingredients.Eggs{}
#     IO.inspect(egg)

#     Kitchen.Techniques.Poach.recipe(egg)
#     |> IO.inspect()
#   end
# end

# Thing.bar()
