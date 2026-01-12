defmodule ReadabilityEx.Fixture_lifehacker_post_comment_loadTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "lifehacker-post-comment-load"

  test "Readability fixture lifehacker-post-comment-load" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
