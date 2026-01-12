This is the **exhaustive technical specification** of the `Readability.js` engine, incorporating all precision adjustments regarding ARIA roles, scoring thresholds, and conditional cleaning logic.

---

# Readability.js: The Definitive Technical Specification

## 0. Result Schema (Output)
The `parse()` method returns a Plain Old JavaScript Object (POJO):
*   **title**: Cleaned article title.
*   **content**: The finalized, sanitized HTML article body.
*   **textContent**: The raw text content (no HTML tags).
*   **length**: Character count of the `textContent`.
*   **excerpt**: A short summary (from meta-description or first paragraph).
*   **byline**: Author credits.
*   **dir**: Text direction (detected by crawling ancestors of the top candidate).
*   **siteName**: Name of the publication/website.
*   **lang**: Content language code (from `<html>` or ancestors).
*   **publishedTime**: Article publication date (from metadata).

---

## Phase 1: Pre-Processing ("Phase Zero")
The engine first prepares the raw DOM for modern web patterns before any scoring takes place.

### 1.1 `_unwrapNoscriptImages`
1.  **Remove Placeholder Images**: Scans for `<img>` tags without a `src` or with very small base64 URIs ($< 133$ bytes).
2.  **NoScript Swap**: Scans for `<noscript>` tags containing exactly one `<img>`. If the previous sibling is an `<img>` (placeholder), the engine replaces the placeholder with the `<noscript>` content. Attributes like `alt` and `title` are merged.

### 1.2 `_removeScripts`
*   Removes all `<script>` and `<noscript>` tags to prevent script execution and noise in text density calculations.

---

## Phase 2: Metadata & Title Extraction

### 2.1 Metadata Extraction (`_getJSONLD` & `_getArticleMetadata`)
*   **JSON-LD**: Prioritizes Schema.org types (`Article`, `NewsArticle`, `BlogPosting`). Resolves `name` vs `headline` by checking which one matches the document title more closely.
*   **Meta Tags**: Extracts from OpenGraph, Twitter, Parsely, and Dublin Core.
*   **Text Direction (`dir`)**: Instead of checking the `<body>`, the engine starts at the `topCandidate` and crawls up its ancestors to find the first node with a valid `dir` attribute.

### 2.2 Title Refinement (`_getArticleTitle`)
*   **Heuristic**: Splits `<title>` by separators (`|`, `-`, `»`, etc.). 
*   **Logic**: If splitting the title reduces the word count to $\le 4$, it verifies if site-name removal was too aggressive by comparing to word counts of the original string.
*   **Verification**: Checks if the extracted title matches an `<h1>` or `<h2>` within the body to ensure it's not just a site-wide tag.

---

## Phase 3: The Sieve (Scoring Engine)

### 3.1 Initial Filtering & ARIA Roles
Nodes are removed immediately if:
1.  **Visibility**: `display:none`, `visibility:hidden`, or `hidden` attribute.
2.  **ARIA Roles**: The element matches any of the following `UNLIKELY_ROLES`: 
    *   `menu`, `menubar`, `complementary`, `navigation`, `alert`, `alertdialog`, `dialog`.
3.  **Semantic Junk**: Matches `unlikelyCandidates` regex (ad, footer, sidebar) and does not match `okMaybeItsACandidate`.
4.  **Empty Blocks**: `DIV`, `SECTION`, `HEADER`, or `H1-H6` that have no text, images, or videos.

### 3.2 The Scoring Algorithm
Nodes (`P`, `TD`, `PRE`, `BLOCKQUOTE`) receive a **Content Score**:
1.  **Base Score**: `DIV`: +5 | `PRE`, `TD`, `BLOCKQUOTE`: +3 | `H1-H6`, `TH`: -5.
2.  **Class/ID Weighting (`_getClassWeight`)**:
    *   Matches `positive` regex: **+25**.
    *   Matches `negative` regex: **-25**.
3.  **Text Heuristics**:
    *   **Commas**: Every segment found via `split(commas)` adds **+1**.
    *   **Length**: For every 100 characters, add **+1** (Max +3).
4.  **Propagation**: Score is added to ancestors:
    *   **Parent**: 100% | **Grandparent**: 50% | **Higher**: `score / (level * 3)`.

---

## Phase 4: Candidate Promotion & Sibling Joining

### 4.1 Hierarchical Promotion (Fragmented Content Fix)
If multiple candidates have scores within 75% of the `topCandidate`:
*   The engine searches for a common ancestor that contains at least **3** of these candidates.
*   If found, that ancestor is promoted to the `topCandidate`. This prevents the algorithm from selecting only one "column" of a multi-column article.

### 4.2 Sibling Joining Logic
Siblings of the `topCandidate` are appended to the content if:
1.  **Score Threshold**: `sibling.score + bonus >= Max(10, topScore * 0.2)`.
    *   *Bonus*: If sibling has the exact same `class` as the `topCandidate`.
2.  **Paragraph Heuristic**: Sibling is a `<p>` with `length > 80` and `linkDensity < 0.25`.

---

## Phase 5: Sanitization & Content Recovery

### 5.1 `_fixLazyImages`
*   **Placeholder Removal**: Strips base64 URIs if the node has other attributes pointing to image files.
*   **Lazy Promotion**: Maps `data-src`, `data-srcset`, and other common lazy-loading attributes to real `src`/`srcset`.
*   **Figure Fix**: If a `<figure>` is empty but contains image-related data-attributes, a new `<img>` is dynamically injected.

### 5.2 `_cleanConditionally` (Semantic Anti-Noise)
Removes elements (`DIV`, `UL`, `TABLE`) based on "shadiness":
1.  **Strict Weight Check**: Node is removed if `(weight + contentScore) < 0`.
2.  **Anti-Noise Words**: Uses `adWords` and `loadingWords` (supporting i18n). If text matches exactly (e.g., "Advertisement", "广告"), the node is removed regardless of score.
3.  **Density Metrics**:
    *   **Heading Density**: Ratio of header text to total text.
    *   **Text Density**: Ratio of text in meaningful tags (`P`, `LI`, `SPAN`) to total text.
4.  **Bad Ratios**: Removed if `img > p` (unless in a gallery) or if `li > p` inside a non-list container.

---

## Phase 6: Structural Post-Processing

### 6.1 `_simplifyNestedElements`
*   **Wrapper Dissolution**: If a `DIV` or `SECTION` contains only one structural child (another `DIV` or `SECTION`) and no meaningful text, the parent is removed and the child is promoted.
*   **Attribute Preservation**: Attributes from the parent (like `id` or `class`) are cloned onto the promoted child.

### 6.2 Final Formatting
1.  **Relative URIs**: Resolves all `<a>`, `<img>`, `<video>`, and `<audio>` links to absolute URLs using `doc.baseURI`.
2.  **Attribute Stripping**: Removes all `style` and presentational attributes (`align`, `bgcolor`, `border`).
3.  **Class Cleaning**: Strips all classes except those explicitly preserved (e.g., `page`).

---

## Phase 7: The Multi-Pass Strategy
If the final `textContent.length < 500` (default `charThreshold`), `parse()` resets and retries:
1.  **Pass 1**: Full heuristics.
2.  **Pass 2**: Disable `FLAG_STRIP_UNLIKELYS`.
3.  **Pass 3**: Disable `FLAG_WEIGHT_CLASSES`.
4.  **Pass 4**: Disable `FLAG_CLEAN_CONDITIONALLY`.

If all passes result in low content, the engine returns the result from the attempt that yielded the **longest text content**.
