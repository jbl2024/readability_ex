defmodule ReadabilityEx.Fixture_remove_aria_hiddenTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "remove-aria-hidden"

  test "Readability fixture remove-aria-hidden" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
