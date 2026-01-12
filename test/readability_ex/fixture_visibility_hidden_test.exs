defmodule ReadabilityEx.Fixture_visibility_hiddenTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "visibility-hidden"

  test "Readability fixture visibility-hidden" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
