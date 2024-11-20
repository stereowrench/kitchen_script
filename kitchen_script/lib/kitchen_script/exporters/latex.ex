defmodule KitchenScript.Exporters.LaTeX do
  def preamble(title, author) do
    """
    \\documentclass{article}

    \\usepackage{varioref}
    \\usepackage[hidelinks]{hyperref}
    \\usepackage{cleveref}
    \\usepackage{enumitem}
    \\usepackage{xfrac}
    \\setlist{nosep}
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
    whole = floor(qty)
    part = qty - whole

    # nearest half
    # half = Float.round(part * 2) / 2
    third = Float.round(part * 3) / 3
    half = Float.round(part * 2) / 2
    quarter = Float.round(part * 4) / 4
    eighth = Float.round(part * 8) / 8

    my_min =
      Enum.min_by([{third, 3}, {half, 2}, {quarter, 4}, {eighth, 8}], fn {a, _} ->
        abs(part - a)
      end)

    {n, b} = my_min
    numerator = round(n * b)
    denom = b

    part_fraction = if n > 0, do: "\\sfrac{#{numerator}}{#{denom}}", else: ""
    whole_str = if whole > 0, do: "#{whole} ", else: ""
    "\\emph{#{whole_str}#{part_fraction} #{unit}}"
  end

  def time_string({q, :hours}) do
    m = (q - floor(q)) * 60

    if m > 0 do
      "(#{q}h#{m}) "
    else
      "(#{q} hours) "
    end
  end

  def time_string({q, :minutes}) do
    "(#{q} minutes) "
  end

  def time_string(nil), do: ""

  def render_steps(steps, ingredients) do
    bindings =
      for %{label: label, qty: qty, ingredient: name} <- ingredients do
        {label, render_unit(qty) <> " #{name}"}
      end

    for {step, time} <- steps, into: "" do
      "\\item #{time_string(time)}" <> EEx.eval_string(step, assigns: bindings) <> "\n"
    end
  end

  defp format_yield({q, unit}) do
    "#{q} #{unit}"
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

    note =
      if recipe.note do
        "\\footnote{#{recipe.note}}"
      else
        ""
      end

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
    \\emph{Makes #{format_yield(recipe.makes)}#{note}}

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
    File.write!("latex/exported.tex", str)
  end
end
