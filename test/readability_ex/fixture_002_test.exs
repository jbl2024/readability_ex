defmodule ReadabilityEx.Fixture_002Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "002"

  test "Readability fixture 002" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
