defmodule ReadabilityEx.Fixture_invalid_attributesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "invalid-attributes"

  test "Readability fixture invalid-attributes" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
