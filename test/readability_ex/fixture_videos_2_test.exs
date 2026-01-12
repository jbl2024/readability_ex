defmodule ReadabilityEx.Fixture_videos_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "videos-2"

  test "Readability fixture videos-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
