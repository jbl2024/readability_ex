defmodule ReadabilityEx.Fixture_youthTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "youth"

  test "Readability fixture youth" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
