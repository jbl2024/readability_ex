defmodule ReadabilityEx.Fixture_keep_tabular_dataTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "keep-tabular-data"

  test "Readability fixture keep-tabular-data" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
