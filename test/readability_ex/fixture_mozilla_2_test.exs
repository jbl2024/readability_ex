defmodule ReadabilityEx.Fixture_mozilla_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "mozilla-2"

  test "Readability fixture mozilla-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
