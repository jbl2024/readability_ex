defmodule ReadabilityEx.Fixture_firefox_nightly_blogTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "firefox-nightly-blog"

  test "Readability fixture firefox-nightly-blog" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
