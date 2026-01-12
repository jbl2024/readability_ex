defmodule ReadabilityEx.Fixture_salon_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "salon-1"

  test "Readability fixture salon-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
