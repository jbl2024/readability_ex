defmodule ReadabilityEx.Fixture_v8_blogTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "v8-blog"

  test "Readability fixture v8-blog" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
