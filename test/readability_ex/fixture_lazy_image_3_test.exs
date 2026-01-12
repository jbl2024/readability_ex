defmodule ReadabilityEx.Fixture_lazy_image_3Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "lazy-image-3"

  test "Readability fixture lazy-image-3" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
