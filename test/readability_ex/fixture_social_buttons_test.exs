defmodule ReadabilityEx.Fixture_social_buttonsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "social-buttons"

  test "Readability fixture social-buttons" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
