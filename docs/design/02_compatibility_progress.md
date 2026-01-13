# Readability.js Compatibility Progress

This document tracks parity between the JavaScript Readability.js implementation
and the current Elixir port in this repository. It highlights the main algorithm
areas, what is already aligned, and where gaps remain.

## Core Pipeline

- Constructor/options/flags
  - Status: Partial
  - Notes: Options like debug, keepClasses, allowedVideoRegex,
    linkDensityModifier, and maxElemsToParse are not fully exposed/used.

- parse() orchestration (noscript, JSON-LD, scripts removal, prep, grab, post-process, excerpt)
  - Status: Partial
  - Notes: Flow is close; still missing per-pass behavior and some metadata
    precedence details.

## Pre-processing

- _unwrapNoscriptImages
  - Status: Matched (behaviorally close)

- _removeScripts
  - Status: Partial
  - Notes: JS removes script + noscript; Elixir removes extra tags and can
    differ on edge cases.

- _prepDocument (style tags, BR replacement, font->span)
  - Status: Partial
  - Notes: BR replacement aligned; style removal differs (JS removes style tags
    only in head).

- _replaceBrs
  - Status: Matched (gated on double-BR)

- _setNodeTag / DOM rewrite
  - Status: Partial
  - Notes: JS preserves attributes and readability fields; Elixir only rewrites tag.

## Visibility & Filtering

- _isProbablyVisible
  - Status: Partial
  - Notes: Elixir visibility is computed once at index build; JS checks live.

- UNLIKELY_ROLES removal
  - Status: Matched

- Unlikely candidates + ancestor checks
  - Status: Matched (core), Partial (edge)

- Remove empty containers (DIV/SECTION/HEADER/Hx)
  - Status: Matched

## Byline

- _isValidByline + remove/record
  - Status: Partial
  - Notes: JS prefers [itemprop="name"] under author nodes; Elixir does not yet.

## Scoring / Candidates

- DEFAULT_TAGS_TO_SCORE
  - Status: Matched

- Ancestor scoring with class weights
  - Status: Matched (core)

- Class/id weight
  - Status: Matched (core)

- Link density weighting (hash links discount)
  - Status: Matched

## Top Candidate Selection

- Top candidates list + link density scaling
  - Status: Matched

- Alternative candidate promotion (common ancestor)
  - Status: Matched (core)

- Parent score promotion
  - Status: Matched (core)

- Only-child promotion
  - Status: Matched

## Sibling Joining

- Sibling threshold + bonus + paragraph heuristics
  - Status: Partial
  - Notes: Close to JS, with extra sibling inclusion for lists/separators/media-only paragraphs.

## Post-processing

- _postProcessContent (fix URIs, simplify nested, clean classes)
  - Status: Partial
  - Notes: JS uses _cleanClasses with keepClasses toggle; Elixir still strips
    additional attributes beyond class cleanup.

- _fixRelativeUris
  - Status: Partial
  - Notes: JS keeps hash links when base == document; Elixir uses an option and
    may differ.

- _simplifyNestedElements
  - Status: Partial
  - Notes: Elixir includes extra site-specific logic.

## Cleaners (prepArticle)

- _cleanStyles
  - Status: Matched

- _markDataTables + _getRowAndColumnCount
  - Status: Matched

- _fixLazyImages
  - Status: Matched (close)

- _cleanConditionally
  - Status: Matched

- _clean for object/embed/iframe/form/footer/link/aside
  - Status: Partial
  - Notes: Elixir includes extra site-specific removal rules.

- _cleanMatchedNodes (share elements)
  - Status: Matched

- _cleanHeaders
  - Status: Matched

- H1 -> H2 replacement
  - Status: Matched

- Remove empty paragraphs
  - Status: Partial
  - Notes: Elixir removes empty nodes differently than JS paragraph rule.

- Remove <br> before <p>
  - Status: Matched

- Single-cell tables (flatten)
  - Status: Matched

- JavaScript link conversion
  - Status: Matched

## Metadata

- _getJSONLD (context/type validation, name/headline similarity)
  - Status: Matched

- _getArticleMetadata (meta tag rules)
  - Status: Matched

- _unescapeHtmlEntities
  - Status: Matched

## Title

- _getArticleTitle
  - Status: Matched (meta title precedence aligned)

## Paging / Multi-page

- _findNextPageLink / _getNextPage / _appendNextPage
  - Status: Missing

## High-impact Gaps (likely to affect fixtures)

1. Paging / multi-page support.
