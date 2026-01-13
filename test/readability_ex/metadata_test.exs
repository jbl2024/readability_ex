defmodule ReadabilityEx.MetadataTest do
  use ExUnit.Case

  alias ReadabilityEx.Metadata

  defp extract(html) do
    doc = Floki.parse_document!(html)
    Metadata.extract(doc, html)
  end

  test "uses weibo meta tags for title and description" do
    html = """
    <html>
      <head>
        <title>Doc Title</title>
        <meta name="weibo:article:title" content="Weibo Title">
        <meta name="weibo:article:description" content="Weibo Desc">
      </head>
      <body></body>
    </html>
    """

    meta = extract(html)

    assert meta.title == "Weibo Title"
    assert meta.excerpt == "Weibo Desc"
  end

  test "filters article:author URLs but accepts other author values" do
    html = """
    <html>
      <head>
        <meta property="article:author" content="https://example.com/author">
        <meta name="author" content="https://example.com/other">
      </head>
      <body></body>
    </html>
    """

    meta = extract(html)

    assert meta.byline == "https://example.com/other"
  end

  test "honors dcterm titles with dot notation" do
    html = """
    <html>
      <head>
        <meta name="dcterm.title" content="Dcterm Title">
        <meta property="og:title" content="OG Title">
      </head>
      <body></body>
    </html>
    """

    meta = extract(html)

    assert meta.title == "Dcterm Title"
  end

  test "ignores og:published_time when article:published_time is missing" do
    html = """
    <html>
      <head>
        <meta property="og:published_time" content="2024-01-01T00:00:00Z">
      </head>
      <body></body>
    </html>
    """

    meta = extract(html)

    assert meta.published_time == nil
  end

  test "uses the first valid JSON-LD block and ignores dateCreated" do
    html = """
    <html>
      <head>
        <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Article",
            "name": "First Title",
            "author": {"name": "First Author"},
            "dateCreated": "2020-01-01"
          }
        </script>
        <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Article",
            "name": "Second Title",
            "author": {"name": "Second Author"},
            "datePublished": "2021-01-01"
          }
        </script>
      </head>
      <body></body>
    </html>
    """

    meta = extract(html)

    assert meta.title == "First Title"
    assert meta.published_time == nil
  end
end
