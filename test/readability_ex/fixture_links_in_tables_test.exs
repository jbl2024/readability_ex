defmodule ReadabilityEx.Fixture_links_in_tablesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "links-in-tables"

  test "Readability fixture links-in-tables" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
