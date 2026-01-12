defmodule ReadabilityEx.Fixture_title_en_dashTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "title-en-dash"

  test "Readability fixture title-en-dash" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
