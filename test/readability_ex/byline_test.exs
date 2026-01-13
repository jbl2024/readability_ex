defmodule ReadabilityEx.BylineTest do
  use ExUnit.Case

  test "uses itemprop name for byline extraction" do
    html = """
    <html>
      <head><title>Example</title></head>
      <body>
        <article>
          <div class="byline" itemprop="author">
            <span itemprop="name">Jane Doe</span>
          </div>
          <p>Sample content for extraction.</p>
        </article>
      </body>
    </html>
    """

    {:ok, result} = ReadabilityEx.parse(html, char_threshold: 0)

    assert result.byline == "Jane Doe"
  end

  test "keeps byline nodes when metadata byline exists" do
    html = """
    <html>
      <head>
        <title>Example</title>
        <meta name="author" content="Meta Author">
      </head>
      <body>
        <article>
          <div class="byline">Byline Node</div>
          <p>Sample content for extraction.</p>
        </article>
      </body>
    </html>
    """

    {:ok, result} = ReadabilityEx.parse(html, char_threshold: 0)

    assert result.byline == "Meta Author"
    assert String.contains?(result.content, "Byline Node")
  end
end
