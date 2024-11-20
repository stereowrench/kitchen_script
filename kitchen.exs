defmodule Recipe do
  defstruct [:name, :ingredients, :steps, :makes, :servings]
end

defmodule Ingredient do
  defstruct [:label, :ingredient, :qty]
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
        qty: unquote(qty)
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
      for %{label: label, qty: qty} <- ingredients do
        {label, render_unit(qty)}
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

  defmacro make(qty, name) when is_integer(qty) do
    quote do
      unless is_integer(unquote(qty)) do
        raise "Only integer servings"
      end

      recipe = Enum.find(@kitchen_recipes, &(&1.name == unquote(name)))

      unless recipe do
        raise "no recipe"
      end

      scale = unquote(qty) / recipe.servings

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
    end
  end

  # TODO scale units
  # defmacro make({qty, unit}, name) when is_integer(qty) do
  #   quote do
  #     unless is_integer(unquote(qty)) do
  #       raise "Only integer servings"
  #     end

  #     recipe = Enum.find(@kitchen_recipes, &(&1.name == unquote(name)))

  #     unless recipe do
  #       raise "no recipe"
  #     end

  #     scale = unquote(qty) / recipe.makes

  #     # TODO limit scale down

  #     ingredients = Kitchen.scale_down_ingredients(recipe.ingredients, scale)

  #     @kitchen_final %Recipe{
  #       name: recipe.name,
  #       ingredients: ingredients,
  #       steps: Kitchen.render_steps(recipe.steps, ingredients),
  #       makes: unquote(qty)
  #     }
  #   end
  # end

  defmacro print_kitchen() do
    quote do
      for recipe <- @kitchen_final do
        grouped_ingredients = Enum.group_by(recipe.ingredients, & &1.ingredient)
        ingredient_list =
          for {place, {name, ingredients}} <-
                Enum.zip(1..length(Map.keys(grouped_ingredients)), grouped_ingredients) do
            # TODO unit conversion and summation
            # total =
            #   ingredients
            #   |> Enum.map(& &1.qty)
            #   |> Enum.sum()

            if length(ingredients) == 1 do
              [ingredient] = ingredients
              "#{place}. #{render_unit(ingredient.qty)} #{ingredient.ingredient}\n"
            else
              each =
                for ea <- ingredients do
                  String.pad_leading("#{ea.label} - #{render_unit(ea.qty)}", length(place) + 1)
                end
                |> Enum.join("\n")

              """
              #{place}. #{name}
              #{each}
              """
            end
          end

        step_list =
          for {place, step} <- Enum.zip(1..length(recipe.steps), recipe.steps) do
            "#{place}. #{step}"
          end

        IO.puts("""
        #{recipe.name}

        # Ingredients
        #{ingredient_list}

        # Steps
        #{step_list}

        #{inspect @kitchen_prep_list}
        #{inspect @kitchen_shopping_list}
        """)
      end
    end
  end

  defmacro source(a = {:ingredient, _line, _body}) do
    quote do
      unquote(a)
      @kitchen_shopping_list @kitchen_ingredient
    end
  end

  defmacro make(a = {:ingredient, _line, _body}) do
    quote do
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
    source ingredient(:baz, "baz", {1, :cup})
  end

  recipe "creme brulee" do
    servings(4)

    ingredients do
      source ingredient(:eggs, "eggs", {2, :each})
      source ingredient(:milk, "milk", {1, :cup})
      make ingredient(:foo, "bar ingredient", {1, :cup})
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
