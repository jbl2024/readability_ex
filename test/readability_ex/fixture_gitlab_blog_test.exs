defmodule ReadabilityEx.Fixture_gitlab_blogTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "gitlab-blog"

  test "Readability fixture gitlab-blog" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
