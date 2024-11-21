# KitchenScript

KitchenScript is an Elixir DSL for managing recipes.

## Features

- [x] Recipe dependencies
- [x] Per-ingredient minimum quantities
- [x] Recipe scaling
- [x] Total ingredient summation
- [x] Minimum recipe scale
- [ ] Substitutes

## Example

```elixir
defmodule MyRecipe do
  use KitchenScript

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

  print_kitchen(:latex)
end
```
