defmodule ReadabilityEx.Fixture_lazy_image_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "lazy-image-1"

  test "Readability fixture lazy-image-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
