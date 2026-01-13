defmodule ReadabilityEx.PagingTest do
  use ExUnit.Case

  test "appends next page content when page_fetcher is provided" do
    page1 = """
    <html>
      <head><title>Page 1</title></head>
      <body>
        <article>
          <p>Page one content.</p>
          <a rel="next" href="/page2">Next</a>
        </article>
      </body>
    </html>
    """

    page2 = """
    <html>
      <head><title>Page 2</title></head>
      <body>
        <article>
          <p>Page two content.</p>
        </article>
      </body>
    </html>
    """

    fetcher = fn
      "https://example.com/page2" -> {:ok, page2}
      _ -> {:error, :not_found}
    end

    {:ok, result} =
      ReadabilityEx.parse(page1,
        char_threshold: 0,
        base_uri: "https://example.com/page1",
        page_fetcher: fetcher,
        max_pages: 1
      )

    assert String.contains?(result.content, "readability-page-1")
    assert String.contains?(result.content, "readability-page-2")
    assert String.contains?(result.content, "Page one content.")
    assert String.contains?(result.content, "Page two content.")
  end
end
