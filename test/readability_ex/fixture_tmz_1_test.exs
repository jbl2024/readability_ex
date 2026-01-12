defmodule ReadabilityEx.Fixture_tmz_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "tmz-1"

  test "Readability fixture tmz-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
