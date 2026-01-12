defmodule ReadabilityEx.Fixture_embedded_videosTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "embedded-videos"

  test "Readability fixture embedded-videos" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
