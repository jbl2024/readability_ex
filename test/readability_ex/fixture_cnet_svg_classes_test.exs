defmodule ReadabilityEx.Fixture_cnet_svg_classesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "cnet-svg-classes"

  test "Readability fixture cnet-svg-classes" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
