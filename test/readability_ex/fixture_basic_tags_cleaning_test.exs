defmodule ReadabilityEx.Fixture_basic_tags_cleaningTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "basic-tags-cleaning"

  test "Readability fixture basic-tags-cleaning" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
