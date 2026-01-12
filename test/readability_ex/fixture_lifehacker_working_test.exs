defmodule ReadabilityEx.Fixture_lifehacker_workingTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "lifehacker-working"

  test "Readability fixture lifehacker-working" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
