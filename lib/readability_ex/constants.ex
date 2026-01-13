defmodule ReadabilityEx.Constants do
  @moduledoc false

  # Flags
  @flag_strip_unlikelys 0x1
  @flag_weight_classes 0x2
  @flag_clean_conditionally 0x4

  def flag_all(),
    do: bor(@flag_strip_unlikelys, bor(@flag_weight_classes, @flag_clean_conditionally))

  def flag_no_strip_unlikelys(), do: bor(@flag_weight_classes, @flag_clean_conditionally)
  def flag_only_clean_conditionally(), do: @flag_clean_conditionally
  def flag_no_weight_classes(), do: bor(@flag_strip_unlikelys, @flag_clean_conditionally)
  def flag_no_clean_conditionally(), do: bor(@flag_strip_unlikelys, @flag_weight_classes)

  def flag_strip_unlikelys(), do: @flag_strip_unlikelys
  def flag_weight_classes(), do: @flag_weight_classes
  def flag_clean_conditionally(), do: @flag_clean_conditionally

  def has_flag?(flags, f), do: band(flags, f) > 0

  defp bor(a, b), do: Bitwise.bor(a, b)
  defp band(a, b), do: Bitwise.band(a, b)

  # Tag sets
  def candidate_tags(),
    do: MapSet.new(["section", "h2", "h3", "h4", "h5", "h6", "p", "td", "pre"])

  def structural_tags(), do: MapSet.new(["div", "section", "article", "main"])
  def header_tags(), do: MapSet.new(["h1", "h2", "h3", "h4", "h5", "h6"])

  # ARIA roles to drop early (conservative subset, can be extended)
  def unlikely_roles() do
    MapSet.new([
      "menu",
      "menubar",
      "complementary",
      "navigation",
      "alert",
      "alertdialog",
      "dialog"
    ])
  end

  # Regexes (align with your spec; you can pin exact Mozilla regex set per commit if needed)
  def re_positive(),
    do: ~r/article|body|content|entry|hentry|h-entry|main|page|pagination|post|text|blog|story/i

  def re_negative(),
    do:
      ~r/-ad-|hidden|^hid$| hid$| hid |^hid |banner|combx|comment|com-|contact|footer|gdpr|masthead|media|meta|outbrain|promo|related|scroll|share|shoutbox|sidebar|skyscraper|sponsor|shopping|tags|widget/i

  def re_unlikely(),
    do:
      ~r/-ad-|ai2html|banner|breadcrumbs|combx|comment|community|cover-wrap|disqus|extra|footer|gdpr|header|legends|menu|related|remark|replies|rss|shoutbox|sidebar|skyscraper|social|sponsor|supplemental|ad-break|agegate|pagination|pager|popup|yom-remote/i

  def re_ok_maybe(), do: ~r/and|article|body|column|content|main|mathjax|shadow/i

  def re_byline(), do: ~r/byline|author|dateline|writtenby|p-author/i

  def re_commas() do
    # All common comma-like characters used by Readability.js
    ~r/[,،﹐︐︑⸁⸴⸲，]/
  end

  def default_char_threshold(), do: 500

  def re_ad_words(),
    do: ~r/^(ad(vertising|vertisement)?|pub(licité)?|werb(ung)?|广告|Реклама|Anuncio)$/iu

  def re_loading_words(),
    do: ~r/^((loading|正在加载|Загрузка|chargement|cargando)(…|\.\.\.)?)$/iu

  def re_share_elements(), do: ~r/(\b|_)(share|sharedaddy)(\b|_)/i

  def allowed_video_re(),
    do:
      ~r/\/\/(www\.)?((dailymotion|youtube|youtube-nocookie|player\.vimeo|v\.qq|bilibili|live\.bilibili)\.com|(archive|upload\.wikimedia)\.org|player\.twitch\.tv)/i

  def lazy_src_attrs() do
    [
      "data-src",
      "data-srcset",
      "data-original",
      "data-orig-src",
      "data-lazy-src",
      "data-lazy-srcset",
      "data-actualsrc",
      "data-hires",
      "data-url",
      "data-img-url",
      "data-image",
      "data-placeholder",
      "data-fullsrc",
      "data-full-src"
    ]
  end

  def urlish_image_re(), do: ~r/\.(png|jpe?g|webp|gif|avif)(\?|#|$)/i
end
