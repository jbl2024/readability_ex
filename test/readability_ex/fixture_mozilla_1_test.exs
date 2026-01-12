defmodule ReadabilityEx.Fixture_mozilla_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "mozilla-1"

  test "Readability fixture mozilla-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
