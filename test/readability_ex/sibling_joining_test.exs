defmodule ReadabilityEx.SiblingJoiningTest do
  use ExUnit.Case

  test "joins qualifying paragraph siblings and skips non-paragraph siblings" do
    long_text =
      String.duplicate("Long sentence with enough words. ", 5)

    html = """
    <html>
      <head><title>Example</title></head>
      <body>
        <div id="main" class="article">
          <p>#{long_text}</p>
          <p>Extra line.</p>
        </div>
        <p id="sib">Short sentence.</p>
        <ul id="list"><li>List item sentence.</li></ul>
      </body>
    </html>
    """

    {:ok, result} = ReadabilityEx.parse(html, char_threshold: 0)

    assert String.contains?(result.content, "Short sentence.")
    assert String.contains?(result.content, long_text)
    assert not String.contains?(result.content, "List item sentence.")
  end
end
