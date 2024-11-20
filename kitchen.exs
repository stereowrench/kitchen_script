defmodule Kitchen.Ingredient do
  defstruct [:label, :ingredient, :qty, :recipe]
end

defprotocol Kitchen.Techniques.Poach do
  @spec recipe(t) :: Kitchen.Recipe.t()
  def recipe(t)
end

defmodule Kitchen.Recipe do
  alias Kitchen.Recipe

  @type t :: %__MODULE__{
          name: String.t(),
          ingredients: [%Kitchen.Ingredient{}],
          steps: [String.t()],
          makes: {integer(), atom()},
          servings: atom()
        }
  defstruct [:name, :ingredients, :steps, :makes, :servings]

  defmodule RecipeMacros do
    alias Kitchen.Ingredient

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
          Enum.map(unquote(ingredients), &Kitchen.Recipe.RecipeMacros.create_ingredient(&1))
      end
    end

    defmacro ingredients(do: sub) do
      quote do
        var!(ingredients) = [Kitchen.Recipe.RecipeMacros.create_ingredient(unquote(sub))]
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

      %Kitchen.Recipe{
        name: unquote(name),
        ingredients: var!(ingredients),
        steps: var!(steps),
        makes: var!(makes),
        servings: var!(servings)
      }
    end
  end
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
  require Kitchen.Recipe
  alias Kitchen.Recipe

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
    Enum.sort_by(recipes, & &1, fn x, y ->
      if x.name in Enum.map(y.ingredients, & &1.recipe) do
        true
      else
        false
      end
    end)
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
        RecipeUnits.total(Enum.map(ingredient, & &1.qty))

      IO.puts("- #{Kitchen.render_unit(scaled)} x #{name}")
    end

    IO.puts("")
  end

  defmacro print_kitchen() do
    quote location: :keep do
      recipes = Kitchen.order_recipes(List.flatten(@kitchen_final))
      # TODO shopping list
      Kitchen.gather_ingredients(recipes)

      for recipe <- recipes do
        grouped_ingredients = Enum.group_by(recipe.ingredients, & &1.ingredient)

        ingredient_list =
          for {place, {name, ingredients}} <-
                Enum.zip(1..length(Map.keys(grouped_ingredients)), grouped_ingredients) do
            total =
              ingredients
              |> Enum.map(& &1.qty)
              |> RecipeUnits.total()

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
          for {place, step} <- Enum.zip(1..length(recipe.steps), recipe.steps) do
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
end

defmodule Kitchen.Ingredients.Eggs do
  defstruct []
end

defimpl Kitchen.Techniques.Poach, for: Kitchen.Ingredients.Eggs do
  alias Kitchen.Recipe
  require Recipe

  def recipe(_egg) do
    Recipe.recipe "poached egg" do
      makes(1)
      servings(0.5)

      ingredients do
        source(ingredient(:eggs, "eggs", {1, :each}))
        make(ingredient(:eggs2, "eggs", {1, :each}))
      end

      steps do
        step("""
        Bring pot to a simmer.
        """)

        step("""
        Gently place <%= @eggs %> into the water.
        """)

        step("""
        Cook for 4 minutes.
        """)
      end
    end
  end
end

defmodule MyRecipe do
  use Kitchen

  recipe "bar ingredient" do
    servings(2)
    makes({2, :cup})

    ingredients do
      source(ingredient(:baz, "baz", {1, :cup}))
    end

    steps do
      step("Whisk it")
    end
  end

  recipe "creme brulee" do
    servings(4)
    makes({1, :cup})

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

defmodule Thing do
  def bar() do
    egg = %Kitchen.Ingredients.Eggs{}
    IO.inspect(egg)

    Kitchen.Techniques.Poach.recipe(egg)
    |> IO.inspect()
  end
end

Thing.bar()
