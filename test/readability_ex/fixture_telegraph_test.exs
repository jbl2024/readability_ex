defmodule ReadabilityEx.Fixture_telegraphTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "telegraph"

  test "Readability fixture telegraph" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
