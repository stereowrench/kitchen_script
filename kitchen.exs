defmodule Recipe do
  defstruct [:name, :ingredients, :steps, :makes, :servings]
end

defmodule Ingredient do
  defstruct [:label, :ingredient, :qty, :recipe]
end

defmodule RecipeUnits do
  def scale_down({q, :quart}) do
    scale_down({q * 2, :pint})
  end

  def scale_down({q, :pint}) do
    scale_down({q * 2, :cup})
  end

  def scale_down({q, :cup}) do
    scale_down({q * 8, :oz})
  end

  def scale_down({q, :oz}) do
    scale_down({q * 2, :tbsp})
  end

  def scale_down({q, :tbsp}) do
    {q * 3, :tsp}
  end

  def scale_up({q, :tsp}) when q < 3, do: {q, :tsp}
  def scale_up({q, :tsp}) when q < 12, do: {q / 12, :tbsp}
  def scale_up({q, :tsp}) when q < 48, do: {q / 48, :cup}
  def scale_up({q, :tsp}) when q < 192, do: {q / 192, :pint}
  def scale_up({q, :tsp}) when q < 768, do: {q / 768, :quart}
  def scale_up({q, :tsp}), do: {q / 768, :gallon}

  def scale(m = {_, :each}), do: m

  def scale(m) do
    m
    |> scale_down()
    |> scale_up()
  end

  def total(measurements = [{_, :each} | _]) do
    t =
      for {q, :each} <- measurements do
        q
      end
      |> Enum.sum()

    {t, :each}
  end

  def total(measurements) do
    t =
      for m <- measurements do
        scale_down(m)
      end
      |> Enum.map(fn {q, :tsp} -> q end)
      |> Enum.sum()

    scale_up({t, :tsp})
  end
end

defmodule Kitchen do
  defmacro __using__(_) do
    quote do
      import Kitchen

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
      if Enum.find(@kitchen_recipes, &(&1.name == unquote(name))) do
        raise "Recipe already exists"
      end

      unquote(recipe_instrs)

      @kitchen_recipes %Recipe{
        name: unquote(name),
        ingredients: @kitchen_ingredients,
        steps: @kitchen_steps,
        makes: @kitchen_makes,
        servings: @kitchen_servings
      }

      Module.delete_attribute(__MODULE__, :kitchen_ingredients)
      Module.delete_attribute(__MODULE__, :kitchen_steps)
      # Module.delete_attribute(__MODULE__, :kitchen_makes)
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

  defmacro ingredient(label, name, qty) do
    quote do
      if Enum.find(@kitchen_ingredients, &(&1.label == unquote(label))) do
        raise "Duplicate item"
      end

      ing = %Ingredient{
        label: unquote(label),
        ingredient: unquote(name),
        qty: unquote(qty),
        recipe: if(@kitchen_make_recipe, do: unquote(name))
      }

      @kitchen_ingredients ing
      @kitchen_ingredient ing
    end
  end

  defmacro step(instructions) do
    quote do
      @kitchen_steps unquote(instructions)
      # EEx.eval_string(unquote(instructions), @kitchen_ingredient_bindings)
    end
  end

  defmacro makes(qty) do
    quote do
      @kitchen_makes unquote(qty)
    end
  end

  defmacro servings(qty) do
    quote do
      @kitchen_servings unquote(qty)
    end
  end

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

  def scale_down_ingredients(ingredients, scale) do
    for ingredient = %{qty: {d, unit}} <- ingredients do
      %{ingredient | qty: RecipeUnits.scale({d * scale, unit})}
    end
  end

  defmacro make(qty, name, remainder \\ nil) do
    quote do
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
            RecipeUnits.scale_down(unquote(qty))

          {b, :tsp} = RecipeUnits.scale_down(recipe.makes)

          a / b
        end

      # TODO limit scale down

      ingredients = Kitchen.scale_down_ingredients(recipe.ingredients, scale)

      {q, unit} = recipe.makes

      @kitchen_final %Recipe{
        name: recipe.name,
        ingredients: ingredients,
        steps: Kitchen.render_steps(recipe.steps, ingredients),
        makes: RecipeUnits.scale({q * scale, unit}),
        servings: unquote(qty)
      }

      @kitchen_final_hold @kitchen_final
      Module.delete_attribute(__MODULE__, :kitchen_final)

      @kitchen_final Kitchen.process_recipes(@kitchen_final_hold, @kitchen_recipes)
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
    IO.inspect(recipes)

    Enum.sort_by(recipes, & &1, fn x, y ->
      IO.inspect([x, y])

      if x.name in Enum.map(y.ingredients, & &1.recipe) do
        true
      else
        false
      end
    end)
  end

  defmacro print_kitchen() do
    quote do
      for recipe <- Kitchen.order_recipes(List.flatten(@kitchen_final)) do
        grouped_ingredients = Enum.group_by(recipe.ingredients, & &1.ingredient)

        ingredient_list =
          for {place, {name, ingredients}} <-
                Enum.zip(1..length(Map.keys(grouped_ingredients)), grouped_ingredients) do
            total =
              ingredients
              |> Enum.map(& &1.qty)
              |> RecipeUnits.total()

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
          for {place, step} <- Enum.zip(1..length(recipe.steps), recipe.steps) do
            "#{place}. #{step}"
          end

        IO.puts("""
        # #{recipe.name}

        ## Ingredients
        #{ingredient_list}

        ## Steps
        #{step_list}

        #{inspect(@kitchen_prep_list)}
        #{inspect(@kitchen_shopping_list)}
        """)
      end
    end
  end

  defmacro source(a = {:ingredient, _line, _body}) do
    quote do
      @kitchen_make_recipe false
      unquote(a)
      @kitchen_shopping_list @kitchen_ingredient
    end
  end

  defmacro make(a = {:ingredient, _line, _body}) do
    quote do
      @kitchen_make_recipe true
      unquote(a)
      @kitchen_prep_list @kitchen_ingredient
    end
  end
end

defmodule MyRecipe do
  use Kitchen

  recipe "bar ingredient" do
    servings(2)
    makes({2, :cup})
    source(ingredient(:baz, "baz", {1, :cup}))
  end

  recipe "creme brulee" do
    servings(4)

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
