defmodule ReadabilityEx.Fixture_js_link_replacementTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "js-link-replacement"

  test "Readability fixture js-link-replacement" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
