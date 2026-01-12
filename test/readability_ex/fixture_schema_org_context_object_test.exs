defmodule ReadabilityEx.Fixture_schema_org_context_objectTest do
  use ExUnit.Case

  alias ReadabilityEx.FixtureCase

  @fixture_id "schema-org-context-object"

  test "Readability fixture schema-org-context-object" do
    FixtureCase.run_fixture(@fixture_id)
  end
end
