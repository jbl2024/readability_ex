defmodule ReadabilityEx.Fixture_keep_imagesTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "keep-images"

  test "Readability fixture keep-images" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
