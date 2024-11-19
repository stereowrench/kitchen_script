defmodule Recipe do
  defstruct [:name, :ingredients, :steps]
end

defmodule Ingredient do
  defstruct [:ingredient, :qty]
end

defmodule Kitchen do
  defmacro __using__(_) do
    quote do
      import Kitchen

      Module.register_attribute(__MODULE__, :kitchen_recipes, accumulate: true)
      Module.register_attribute(__MODULE__, :kitchen_steps, accumulate: true)
      Module.register_attribute(__MODULE__, :kitchen_ingredients, accumulate: true)
    end
  end

  defmacro recipe(name, do: recipe_instrs) do
    quote do
      if Enum.find(@kitchen_recipes, &(&1.name == unquote(name))) do
        raise "Recipe already exists"
      end

      unquote(recipe_instrs)

      # IO.inspect(sub)

      # recipes =
      #   Map.put(recipes, unquote(name), %Recipe{
      #     ingredients: sub.ingredients
      #     # steps: sub.steps
      #   })

      @kitchen_recipes %Recipe{
        name: unquote(name),
        ingredients: @kitchen_ingredients,
        steps: @kitchen_steps
      }
      Module.delete_attribute(__MODULE__, :kitchen_ingredients)
    end
  end

  defmacro ingredients(do: ingredients) do
    quote do
      unquote(ingredients)
    end
  end

  defmacro steps(do: steps) do
    quote do
      unquote(steps)
    end
  end

  defmacro ingredient(name, qty) do
    quote do
      @kitchen_ingredients %Ingredient{ingredient: unquote(name), qty: unquote(qty)}
    end
  end
end

defmodule MyRecipe do
  use Kitchen

  recipe "creme brulee" do
    ingredients do
      ingredient("eggs", {2, :each})
      ingredient("milk", {1, :cup})
    end
  end

  recipe "creme brulee" do
  end

  IO.inspect(@kitchen_recipes)
end
