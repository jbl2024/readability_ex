defmodule ReadabilityEx.Fixture_hukumusumeTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "hukumusume"

  test "Readability fixture hukumusume" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
