defmodule ReadabilityEx.Fixture_google_sre_book_1Test do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "google-sre-book-1"

  test "Readability fixture google-sre-book-1" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
