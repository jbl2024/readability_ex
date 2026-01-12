defmodule ReadabilityEx.Fixture_folhaTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "folha"

  test "Readability fixture folha" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
