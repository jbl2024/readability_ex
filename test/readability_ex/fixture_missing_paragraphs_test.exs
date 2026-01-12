defmodule ReadabilityEx.Fixture_missing_paragraphsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "missing-paragraphs"

  test "Readability fixture missing-paragraphs" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
