defmodule ReadabilityEx.Fixture_remove_extra_brsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "remove-extra-brs"

  test "Readability fixture remove-extra-brs" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
