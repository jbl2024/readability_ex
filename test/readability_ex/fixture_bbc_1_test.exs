defmodule ReadabilityEx.Fixture_bbc_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "bbc-1"

  test "Readability fixture bbc-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
