defmodule ReadabilityEx.Fixture_base_url_base_element_relativeTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "base-url-base-element-relative"

  test "Readability fixture base-url-base-element-relative" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
