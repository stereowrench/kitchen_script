defmodule KitchenScript.Exporters.LaTeX do
  def preamble(title, author) do
    """
    \\documentclass{article}

    \\usepackage{varioref}
    \\usepackage{hyperref}
    \\usepackage{cleveref}
    \\title{#{title}}
    \\author{#{author}}

    \\begin{document}
    \\maketitle
    """
  end

  @endamble """
  \\end{document}
  """

  defp clean_name(name) do
    String.replace(to_string(name), ~r"_", "\\textunderscore{}")
  end

  defp totals(recipes) do
    ingredients =
      recipes
      |> Enum.map(& &1.ingredients)
      |> List.flatten()
      |> Enum.group_by(& &1.ingredient)

    rows =
      for {name, ingredient} <- ingredients do
        name_formatted =
          if hd(ingredient).recipe do
            "\\textbf{#{clean_name(name)}}"
          else
            clean_name(name)
          end

        scaled =
          KitchenScript.RecipeUnits.total(Enum.map(ingredient, & &1.qty))

        "#{name_formatted} & #{render_unit(scaled)}"
      end
      |> Enum.intersperse("\\\\")
      |> Enum.join("\n")

    """
    \\begin{figure}[h]
    \\centering
    \\begin{tabular}{ll}
    \\textbf{Ingredient} & \\textbf{Qty.}\\\\
    \\hline
    """ <>
      rows <>
      """

      \\end{tabular}
      \\end{figure}
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

    for step <- steps, into: "" do
      "\\item " <> EEx.eval_string(step, assigns: bindings) <> "\n"
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

          if ingredient.recipe do
            "\\item #{render_unit(ingredient.qty)} \\textbf{#{ingredient.ingredient}}(\\cref{ingredient:#{ingredient.ingredient}})\n"
          else
            "\\item #{render_unit(ingredient.qty)} #{ingredient.ingredient}\n"
          end
        else
          each =
            for ea <- ingredients do
              "#{clean_name(ea.label)} & #{render_unit(ea.qty)}"
            end
            |> Enum.intersperse("\\\\")
            |> Enum.join("\n")

          """
          \\item #{render_unit(total)} #{clean_name(name)}

          \\begin{tabular}{ll}
          #{each}
          \\end{tabular}
          """
        end
      end

    ingredient_string =
      """
      \\subsection{Ingredients}
      \\begin{enumerate}
      """ <>
        Enum.join(ingredient_list, "\n") <>
        "\\end{enumerate}"

    # for step <- recipe.steps, into: "" do
    #   "\\item #{step}\n"
    # end <>
    steps_string =
      """
      \\subsection{Steps}
      \\begin{enumerate}
      """ <>
        steps <>
        "\\end{enumerate}\n"

    """
    \\section{#{recipe.name}}
    \\label{ingredient:#{recipe.name}}
    """ <>
      ingredient_string <> steps_string
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
    File.write!("exported.tex", str)
  end
end
