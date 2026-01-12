defmodule ReadabilityEx.Fixture_dev418Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "dev418"

  test "Readability fixture dev418" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
