defmodule ReadabilityEx.Fixture_004_metadata_space_separated_propertiesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "004-metadata-space-separated-properties"

  test "Readability fixture 004-metadata-space-separated-properties" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
