defmodule ReadabilityEx.Fixture_remove_extra_paragraphsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "remove-extra-paragraphs"

  test "Readability fixture remove-extra-paragraphs" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
