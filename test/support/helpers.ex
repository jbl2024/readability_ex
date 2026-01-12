defmodule ReadabilityEx.TestHelpers do
  @fixtures_dir "test/fixtures/readability-test-pages"

  def fixture_dirs do
    @fixtures_dir
    |> File.ls!()
    |> Enum.filter(&File.dir?(Path.join(@fixtures_dir, &1)))
    |> Enum.sort()
  end

  def read_fixture(id) do
    base = Path.join(@fixtures_dir, id)

    %{
      id: id,
      source: File.read!(Path.join(base, "source.html")),
      expected_html: File.read!(Path.join(base, "expected.html")),
      expected_meta:
        base
        |> Path.join("expected-metadata.json")
        |> File.read!()
        |> Jason.decode!()
    }
  end

  # Normalisation légère pour comparer du HTML Readability-like
  # Readability.js ne garantit pas les espaces ni l’ordre exact des attributs
  def normalize_html(html) do
    html
    |> Floki.parse_fragment!()
    |> Floki.raw_html()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # Normalisation du texte brut
  def normalize_text(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
