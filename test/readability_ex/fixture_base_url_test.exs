defmodule ReadabilityEx.Fixture_base_urlTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "base-url"

  test "Readability fixture base-url" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
