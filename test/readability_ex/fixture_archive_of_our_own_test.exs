defmodule ReadabilityEx.Fixture_archive_of_our_ownTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "archive-of-our-own"

  test "Readability fixture archive-of-our-own" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
