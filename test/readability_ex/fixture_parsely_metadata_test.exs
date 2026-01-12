defmodule ReadabilityEx.Fixture_parsely_metadataTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "parsely-metadata"

  test "Readability fixture parsely-metadata" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
