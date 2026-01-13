defmodule ReadabilityEx.PrepDocumentTest do
  use ExUnit.Case

  alias ReadabilityEx.Cleaner

  test "remove_scripts removes script and noscript only" do
    html = """
    <html>
      <head>
        <style>.a{color:red}</style>
        <script>console.log("x")</script>
      </head>
      <body>
        <noscript><p>fallback</p></noscript>
        <link rel="preload" as="script" href="/x.js">
      </body>
    </html>
    """

    doc = Floki.parse_document!(html)
    cleaned = Cleaner.remove_scripts(doc)

    assert Floki.find(cleaned, "script") == []
    assert Floki.find(cleaned, "noscript") == []
    assert Floki.find(cleaned, "style") != []
    assert Floki.find(cleaned, "link[rel='preload'][as='script']") != []
  end

  test "prep_document removes head styles but keeps body styles" do
    html = """
    <html>
      <head>
        <style>.a{color:red}</style>
      </head>
      <body>
        <div style="color: blue">ok</div>
      </body>
    </html>
    """

    doc = Floki.parse_document!(html)
    cleaned = Cleaner.prep_document(doc)

    assert Floki.find(cleaned, "head style") == []
    assert Floki.find(cleaned, "*[style]") != []
  end

  test "prep_document replaces double br with paragraph anywhere" do
    html = """
    <html>
      <body>
        <span>alpha<br><br>beta</span>
      </body>
    </html>
    """

    doc = Floki.parse_document!(html)
    cleaned = Cleaner.prep_document(doc)

    assert Floki.find(cleaned, "span p") != []
  end
end
