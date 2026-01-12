defmodule ReadabilityEx.Fixture_dropbox_blogTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "dropbox-blog"

  test "Readability fixture dropbox-blog" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
