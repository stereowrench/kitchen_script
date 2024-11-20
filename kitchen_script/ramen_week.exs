defmodule RamenWeek do
  use KitchenScript

  recipe "tonkotsu broth" do
    # servings(8)
    makes({4, :quart})

    ingredients do
      source(ingredient(:pork_bones, "pork bones", {3, :lb}))
      source(ingredient(:pigs_feet, "pigs feet", {2, :lb}))
      source(ingredient(:onion, "onion", {1, :each}))
      source(ingredient(:water, "water", {14, :cup}))
    end

    steps do
      step("""
        Blanch the pork bones and pigs’ feet. Place them in a large stockpot, cover with cold tap water, and set over high heat. As soon as the water comes to a full boil, remove the pot from the heat. Drain the pot, discarding the water. Rinse the bones well under cold water.
        """)

      step("""
        Refrigerate the blanched, rinsed bones and feet for about 3 hours.
        """, {3, :hours})
    end

  end

  make({2, :tbsp}, "tonkotsu broth")

  print_kitchen(:latex)
end
