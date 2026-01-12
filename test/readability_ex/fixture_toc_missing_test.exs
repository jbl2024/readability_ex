defmodule ReadabilityEx.Fixture_toc_missingTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "toc-missing"

  test "Readability fixture toc-missing" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
