defmodule ReadabilityEx.Fixture_mercurialTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "mercurial"

  test "Readability fixture mercurial" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
