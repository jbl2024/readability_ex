defmodule ReadabilityEx.Fixture_comment_inside_script_parsingTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "comment-inside-script-parsing"

  test "Readability fixture comment-inside-script-parsing" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
