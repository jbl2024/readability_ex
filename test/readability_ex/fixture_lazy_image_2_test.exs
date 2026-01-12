defmodule ReadabilityEx.Fixture_lazy_image_2Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "lazy-image-2"

  test "Readability fixture lazy-image-2" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
