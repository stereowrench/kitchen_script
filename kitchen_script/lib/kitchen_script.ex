defmodule KitchenScript do
  @moduledoc """
  Documentation for `KitchenScript`.
  """

  require KitchenScript.Recipe
  alias KitchenScript.RecipeUnits
  alias KitchenScript.Recipe

  defmacro __using__(_) do
    quote do
      import KitchenScript

      Module.register_attribute(__MODULE__, :kitchen_recipes, accumulate: true)
      Module.register_attribute(__MODULE__, :kitchen_steps, accumulate: true)
      # Module.register_attribute(__MODULE__, :kitchen_makes)
      Module.register_attribute(__MODULE__, :kitchen_ingredients, accumulate: true)
      Module.register_attribute(__MODULE__, :kitchen_final, accumulate: true)

      Module.register_attribute(__MODULE__, :kitchen_shopping_list, accumulate: true)
      Module.register_attribute(__MODULE__, :kitchen_prep_list, accumulate: true)
      # Module.register_attribute(__MODULE__, :kitchen_ingredient_bindings, accumulate: false)
    end
  end

  defmacro recipe(name, do: recipe_instrs) do
    quote do
      require Recipe

      if Enum.find(@kitchen_recipes, &(&1.name == unquote(name))) do
        raise "Recipe already exists"
      end

      # unquote(recipe_instrs)

      # @kitchen_recipes %Recipe{
      #   name: unquote(name),
      #   ingredients: @kitchen_ingredients,
      #   steps: @kitchen_steps,
      #   makes: @kitchen_makes,
      #   servings: @kitchen_servings
      # }

      # Module.delete_attribute(__MODULE__, :kitchen_ingredients)
      # Module.delete_attribute(__MODULE__, :kitchen_steps)

      recipe =
        Recipe.recipe unquote(name) do
          unquote(recipe_instrs)
        end

      if is_nil(recipe.steps) do
        raise "Recipe must have steps"
      end

      @kitchen_recipes recipe
      # Module.delete_attribute(__MODULE__, :kitchen_makes)
    end
  end

  # defmacro step(instructions) do
  #   quote do
  #     @kitchen_steps unquote(instructions)
  #     # EEx.eval_string(unquote(instructions), @kitchen_ingredient_bindings)
  #   end
  # end

  def scale_down_ingredients(ingredients, scale) do
    for ingredient = %{qty: {d, unit}} <- ingredients do
      %{ingredient | qty: KitchenScript.RecipeUnits.scale({d * scale, unit})}
    end
  end

  defmacro make(qty, name, remainder \\ nil) do
    quote location: :keep do
      case unquote(qty) do
        q when is_integer(q) ->
          :ok

        {q, _} ->
          :ok

        _ ->
          raise "Only integer servings"
      end

      qty = unquote(qty)
      remainder = unquote(remainder)
      name = unquote(name)

      recipes =
        if remainder,
          do: remainder,
          else: @kitchen_recipes

      recipe = Enum.find(recipes, &(&1.name == name))

      unless recipe do
        raise "no recipe"
      end

      scale =
        if is_integer(qty) do
          qty / recipe.servings
        else
          {a, :tsp} =
            KitchenScript.RecipeUnits.scale_down(unquote(qty))

          {b, :tsp} = KitchenScript.RecipeUnits.scale_down(recipe.makes)

          a / b
        end

      min_scale =
        for ingredient <- recipe.ingredients do
          if is_atom(ingredient.module) and
               function_exported?(ingredient.module, :min_qty, 0) do
            {q, unit} = ingredient.module.min_qty() |> RecipeUnits.scale_down()
            {qty, _} = RecipeUnits.scale_down(ingredient.qty)
            q / qty
          else
            case RecipeUnits.scale_down(ingredient.qty) do
              {a, :tsp} ->
                1 / (4 * a)

              {a, :oz} ->
                1 / (4 * a)

              {a, :each} ->
                1 / (8 * a)
            end
          end
        end
        |> Enum.sort()
        |> List.last()

      {scale, note} =
        if min_scale > scale do
          {min_scale,
           "Recipe was scaled up to #{Float.round(min_scale, 2)} of a recipe instead of #{scale}."}
        else
          {scale, nil}
        end

      ingredients = KitchenScript.scale_down_ingredients(recipe.ingredients, scale)

      {q, unit} = recipe.makes

      servings = if is_integer(qty), do: qty

      @kitchen_final %Recipe{
        name: recipe.name,
        ingredients: ingredients,
        steps: recipe.steps,
        makes: KitchenScript.RecipeUnits.scale({q * scale, unit}),
        servings: servings,
        note: note
      }

      @kitchen_final_hold @kitchen_final
      Module.delete_attribute(__MODULE__, :kitchen_final)

      @kitchen_final KitchenScript.process_recipes(@kitchen_final_hold, @kitchen_recipes)
    end
  end

  def process_recipes([], _kitchen_recipes), do: []

  def process_recipes(recipe_list, kitchen_recipes) do
    sub_recipes =
      for recipe <- recipe_list do
        for ingredient <- recipe.ingredients do
          if ingredient.recipe, do: ingredient.recipe
        end
      end
      |> List.flatten()
      |> Enum.reject(&is_nil(&1))

    subs =
      kitchen_recipes
      |> Enum.filter(&(&1.name in sub_recipes))

    recursive = process_recipes(subs, kitchen_recipes)

    [recipe_list | recursive] |> List.flatten()
    # TODO merge duplicates
  end

  def order_recipes(recipes) do
    Enum.sort_by(recipes, & &1, fn x, y ->
      if x.name in Enum.map(y.ingredients, & &1.recipe) do
        true
      else
        false
      end
    end)
  end

  defmacro print_kitchen(output \\ :console) do
    quote location: :keep do
      recipes = KitchenScript.order_recipes(List.flatten(@kitchen_final))
      # TODO shopping list
      case unquote(output) do
        :console ->
          KitchenScript.Exporters.Console.export(recipes)

        :latex ->
          KitchenScript.Exporters.LaTeX.export(recipes)
      end
    end
  end
end
