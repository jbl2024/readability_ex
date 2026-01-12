defmodule ReadabilityEx.Fixture_reordering_paragraphsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "reordering-paragraphs"

  test "Readability fixture reordering-paragraphs" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
