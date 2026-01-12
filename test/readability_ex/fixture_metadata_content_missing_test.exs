defmodule ReadabilityEx.Fixture_metadata_content_missingTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "metadata-content-missing"

  test "Readability fixture metadata-content-missing" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
