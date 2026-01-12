defmodule ReadabilityEx.Fixture_base_url_base_elementTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "base-url-base-element"

  test "Readability fixture base-url-base-element" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
