defmodule KitchenScript.Recipe do
  @type t :: %__MODULE__{
          name: String.t(),
          ingredients: [%KitchenScript.Ingredient{}],
          steps: [String.t()],
          makes: {integer(), atom()},
          servings: atom()
        }
  defstruct [:name, :ingredients, :steps, :makes, :servings]

  defmodule RecipeMacros do
    alias KitchenScript.Ingredient

    defmacro source({:ingredient, _, ingredient}) do
      quote do
        {:source, unquote(ingredient)}
      end
    end

    defmacro make({:ingredient, _, ingredient}) do
      quote do
        {:make, unquote(ingredient)}
      end
    end

    def create_ingredient({:make, [label, ingredient, {qty, unit}]}) do
      %Ingredient{
        label: label,
        ingredient: ingredient,
        qty: {qty, unit},
        recipe: ingredient
      }
    end

    def create_ingredient({:source, [label, ingredient, {qty, unit}]}) do
      %Ingredient{
        label: label,
        ingredient: ingredient,
        qty: {qty, unit}
      }
    end

    defmacro ingredients(do: {:__block__, _, ingredients}) do
      quote do
        var!(ingredients) =
          Enum.map(unquote(ingredients), &KitchenScript.Recipe.RecipeMacros.create_ingredient(&1))
      end
    end

    defmacro ingredients(do: sub) do
      quote do
        var!(ingredients) = [KitchenScript.Recipe.RecipeMacros.create_ingredient(unquote(sub))]
      end
    end

    defmacro step(string) do
      quote do
        unquote(string)
      end
    end

    defmacro steps(do: {:__block__, _, steps}) do
      quote do
        var!(steps) = Enum.map(unquote(steps), & &1)
      end
    end

    defmacro steps(do: single) do
      quote do
        var!(steps) = [unquote(single)]
      end
    end

    defmacro makes(qty) do
      quote do
        var!(makes) = unquote(qty)
      end
    end

    defmacro servings(qty) do
      quote do
        var!(servings) = unquote(qty)
      end
    end

    # TODO makes and servings
  end

  defmacro recipe(name, do: recipe_instrs) do
    quote location: :keep do
      import RecipeMacros

      var!(steps) = nil
      var!(makes) = nil
      var!(servings) = nil

      # Hack to make warnings go away
      _hack = var!(steps)
      _hack = var!(makes)
      _hack = var!(servings)

      unquote(recipe_instrs)

      unless var!(makes) do
        raise "Must specify the amount made"
      end

      unless var!(servings) do
        raise "Must specify number of servings"
      end

      %KitchenScript.Recipe{
        name: unquote(name),
        ingredients: var!(ingredients),
        steps: var!(steps),
        makes: var!(makes),
        servings: var!(servings)
      }
    end
  end
end