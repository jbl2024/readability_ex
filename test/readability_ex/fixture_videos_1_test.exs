defmodule ReadabilityEx.Fixture_videos_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "videos-1"

  test "Readability fixture videos-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
