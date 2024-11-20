defmodule RecipeExtractor do
  @moduledoc """
  Documentation for `RecipeExtractor`.
  """
  require IEx

  require Logger

  def extract_from_url(url) do
    case HTTPoison.get(url) do
      {:ok, response} ->
        extract_from_html(response.body)

      {:error, error} ->
        Logger.error("Error fetching HTML: #{inspect(error)}")
        {:error, :fetch_failed}
    end
  end

  def extract_recipe(jsonld) do
    recipe = jsonld |> Enum.find(&(&1["@type"] == ["http://schema.org/Recipe"]))

    # http://schema.org/recipeYield
    # http://schema.org/recipeInstructions
  end

  def extract_from_html(html_content) do
    with {:ok, document} <- Floki.parse_document(html_content),
         jsonld_string <-
           Floki.find(document, "script[type='application/ld+json']") |> Floki.text(js: true),
         {:ok, jsonld_json} <- Jason.decode(jsonld_string),
         loaded <- JSON.LD.expand(jsonld_json) do
      {:ok, loaded}
    else
      error ->
        Logger.error("Error extracting JSON-LD: #{inspect(error)}")
        {:error, :extraction_failed}
    end
  end
end
