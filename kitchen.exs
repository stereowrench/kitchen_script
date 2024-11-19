defmodule Recipe do
  defstruct [:ingredients, :steps]
end

defmodule Ingredient do
  defstruct [:ingredient, :qty]
end

defmodule Kitchen do
  defmacro __using__(_) do
    quote do
      import Kitchen
    end
  end

  defp init_map(name) do
    unless Macro.Env.has_var?(__ENV__, {name, nil}) do
      v = Macro.var(name, __MODULE__)

      quote do
        unquote(v) = %{}
      end
    end
  end

  defp init_list(name) do
    unless Macro.Env.has_var?(__ENV__, {name, nil}) do
      v = Macro.var(name, __MODULE__)

      quote do
        unquote(v) = []
      end
    end
  end

  defmacro recipe(name, do: recipe_instrs) do
    recipes = init_map(:recipes)

    quote do
      unquote(recipes)

      if Map.get(recipes, unquote(name)) do
        raise "Recipe already exists"
      end

      sub = unquote(recipe_instrs)

      IO.inspect(sub)

      recipes =
        Map.put(recipes, unquote(name), %Recipe{
          ingredients: sub.ingredients
          # steps: sub.steps
        })
    end
  end

  defmacro ingredients(do: ingredients) do
    sub = init_map(:sub)

    quote do
      unquote(sub)
      sub = Map.put(sub, :ingredients, unquote(ingredients))
      sub
    end
  end

  defmacro ingredient(name, qty) do
    ings = init_list(:ingredients)

    quote do
      unquote(ings)

      ingredients = [%Ingredient{ingredient: unquote(name), qty: unquote(qty)} | ings]

      ingredients
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
end
