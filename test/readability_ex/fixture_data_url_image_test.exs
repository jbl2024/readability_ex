defmodule ReadabilityEx.Fixture_data_url_imageTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "data-url-image"

  test "Readability fixture data-url-image" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
