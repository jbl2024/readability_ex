defmodule ReadabilityEx.Fixture_svg_parsingTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "svg-parsing"

  test "Readability fixture svg-parsing" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
