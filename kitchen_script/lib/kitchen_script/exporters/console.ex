defmodule KitchenScript.Exporters.Console do
  def render_unit({qty, unit}) do
    "#{qty} #{unit}"
  end

  def render_steps(steps, ingredients) do
    bindings =
      for %{label: label, qty: qty, ingredient: name} <- ingredients do
        {label, render_unit(qty) <> " #{name}"}
      end

    for step <- steps do
      EEx.eval_string(step, assigns: bindings)
    end
  end

  def gather_ingredients(recipes) do
    ingredients =
      recipes
      |> Enum.map(& &1.ingredients)
      |> List.flatten()
      |> Enum.group_by(& &1.ingredient)

    IO.puts("# Ingredients")

    for {name, ingredient} <- ingredients do
      scaled =
        KitchenScript.RecipeUnits.total(Enum.map(ingredient, & &1.qty))

      IO.puts("- #{render_unit(scaled)} x #{name}")
    end

    IO.puts("")
  end

  def export(recipes) do
    gather_ingredients(recipes)

    for recipe <- recipes do
      steps = render_steps(recipe.steps, recipe.ingredients)

      grouped_ingredients = Enum.group_by(recipe.ingredients, & &1.ingredient)

      ingredient_list =
        for {place, {name, ingredients}} <-
              Enum.zip(1..length(Map.keys(grouped_ingredients)), grouped_ingredients) do
          total =
            ingredients
            |> Enum.map(& &1.qty)
            |> KitchenScript.RecipeUnits.total()

          # TODO highlight included recipes
          if length(ingredients) == 1 do
            [ingredient] = ingredients
            "#{place}. #{render_unit(ingredient.qty)} #{ingredient.ingredient}\n"
          else
            each =
              for ea <- ingredients do
                String.duplicate(" ", String.length(to_string(place)) + 2) <>
                  "#{ea.label} - #{render_unit(ea.qty)}"
              end
              |> Enum.join("\n")

            """
            #{place}. #{render_unit(total)} #{name}
            #{each}
            """
          end
        end

      step_list =
        for {place, step} <-
              Enum.zip(1..length(recipe.steps), steps) do
          "#{place}. #{step}"
        end

      IO.puts("""
      ## #{recipe.name}

      ### Ingredients
      #{ingredient_list}

      ### Steps
      #{step_list}
      """)
    end
  end
end
