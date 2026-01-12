defmodule ReadabilityEx.Fixture_remove_script_tagsTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "remove-script-tags"

  test "Readability fixture remove-script-tags" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
