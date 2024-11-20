defmodule KitchenScript.Exporters.LaTeX do
  def preamble(title, author) do
    """
    \\documentclass{article}
    \\title{#{title}}
    \\author{#{author}}

    \\begin{document}
    \\maketitle
    """
  end

  @endamble """
  \\end{document}
  """

  defp totals(recipes) do
    ingredients =
      recipes
      |> Enum.map(& &1.ingredients)
      |> List.flatten()
      |> Enum.group_by(& &1.ingredient)

    rows =
      for {name, ingredient} <- ingredients do
        scaled =
          KitchenScript.RecipeUnits.total(Enum.map(ingredient, & &1.qty))

        "#{ingredient} & #{scaled}"
      end
      |> Enum.join("\n")

    """
    \\begin{tabular}{ll}
    Ingredient & Qty.\\\\
    """ <>
      rows <>
      """
      \\end{tabular}
      """
  end

  defp render_unit({qty, unit}) do
    "#{qty} \\emph{#{unit}}"
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

  defp format_recipe(recipe) do
    steps = render_steps(recipe.steps, recipe.ingredients)

    grouped_ingredients = Enum.group_by(recipe.ingredients, & &1.ingredient)

    ingredient_list =
      for {name, ingredients} <- grouped_ingredients do
        total =
          ingredients
          |> Enum.map(& &1.qty)
          |> KitchenScript.RecipeUnits.total()

        # TODO highlight included recipes
        if length(ingredients) == 1 do
          [ingredient] = ingredients
          "\\item #{render_unit(ingredient.qty)} #{ingredient.ingredient}\n"
        else
          each =
            for ea <- ingredients do
              "#{ea.label} - #{render_unit(ea.qty)}"
            end
            |> Enum.join("\n\n")

          """
          \\item #{render_unit(total)} #{name}

          #{each}
          """
        end
      end

    ingredient_string =
      "\\begin{enumerate}" <>
        Enum.join(ingredient_list, "\n") <>
        "\\end{enumerate}"

    steps_string =
      "\\begin{enumerate}\n" <>
        for step <- recipe.steps do
          "\\item #{step}\n"
        end <>
        "\\end{enumerate}\n"

    steps <> ingredient_string <> steps_string
  end

  defp formatted_recipes(recipes) do
    for recipe <- recipes do
      format_recipe(recipe)
    end
    |> Enum.join("\n")
  end

  def export(recipes) do
    (preamble("Recipes", "John Doe") <>
       totals(recipes) <>
       formatted_recipes(recipes) <>
       @endamble)
    |> write!()
  end

  defp write!(str) do
    File.write!(str, "exported.tex")
  end
end
