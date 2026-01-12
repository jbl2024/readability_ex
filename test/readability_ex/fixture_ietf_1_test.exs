defmodule ReadabilityEx.Fixture_ietf_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "ietf-1"

  test "Readability fixture ietf-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
