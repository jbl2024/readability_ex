defmodule ReadabilityEx.Fixture_bug_1255978Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "bug-1255978"

  test "Readability fixture bug-1255978" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
