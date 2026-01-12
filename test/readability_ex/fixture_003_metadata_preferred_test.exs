defmodule ReadabilityEx.Fixture_003_metadata_preferredTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "003-metadata-preferred"

  test "Readability fixture 003-metadata-preferred" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
