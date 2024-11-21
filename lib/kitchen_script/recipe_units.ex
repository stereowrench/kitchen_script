defmodule KitchenScript.RecipeUnits do
  def scale_down({q, :gallon}) do
    scale_down({q * 4, :quart})
  end

  def scale_down({q, :quart}) do
    scale_down({q * 2, :pint})
  end

  def scale_down({q, :pint}) do
    scale_down({q * 2, :cup})
  end

  def scale_down({q, :cup}) do
    scale_down({q * 8, :fl_oz})
  end

  def scale_down({q, :fl_oz}) do
    scale_down({q * 2, :tbsp})
  end

  def scale_down({q, :tbsp}) do
    {q * 3, :tsp}
  end

  def scale_down({q, :tsp}) do
    {q, :tsp}
  end

  def scale_down({q, :oz}) do
    {q, :oz}
  end

  def scale_down({q, :lb}) do
    {q * 16, :oz}
  end

  def scale_down({q, :each}) do
    {q, :each}
  end

  def scale_up({q, :tsp}) when q < 3, do: {q, :tsp}
  def scale_up({q, :tsp}) when q < 6, do: {q / 3, :tbsp}
  def scale_up({q, :tsp}) when q < 12, do: {q / 6, :fl_oz}
  def scale_up({q, :tsp}) when q < 48, do: {q / 12, :cup}
  def scale_up({q, :tsp}) when q < 192, do: {q / 48, :pint}
  def scale_up({q, :tsp}) when q < 768, do: {q / 192, :quart}
  def scale_up({q, :tsp}), do: {q / 768, :gallon}

  def scale_up({q, :oz}) when q < 16, do: {q, :oz}
  def scale_up({q, :oz}), do: {q / 16, :lb}

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

    # |> Enum.map(fn
    #   {q, :tsp} -> q
    #   {q, :oz} -> q
    #   end)

    {_, unit} = hd(t)

    t =
      t
      |> Enum.map(fn {q, _} -> q end)
      |> Enum.sum()

    scale_up({t, unit})
  end
end
