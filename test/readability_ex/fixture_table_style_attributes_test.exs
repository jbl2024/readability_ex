defmodule ReadabilityEx.Fixture_table_style_attributesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "table-style-attributes"

  test "Readability fixture table-style-attributes" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
