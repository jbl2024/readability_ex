defmodule ReadabilityExTest do
  use ExUnit.Case
  doctest ReadabilityEx

  test "greets the world" do
    assert ReadabilityEx.hello() == :world
  end
end
