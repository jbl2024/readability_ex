defmodule ReadabilityEx.Fixture_medicalnewstodayTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "medicalnewstoday"

  test "Readability fixture medicalnewstoday" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
