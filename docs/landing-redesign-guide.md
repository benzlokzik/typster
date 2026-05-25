# Landing Redesign Guide — "modern but academic"

A working guide for evolving the marketing pages (`/`, future about/pricing/docs)
toward a more current, 2026-coded look **without compromising the academic
positioning** of the product. Read alongside `docs/landing-style.md`, which
documents the current visual language and is the source of truth for tokens.

## Positioning anchor

Typster is an **academic / research / technical-writing tool**. Peer set:

- **typst.app** — closest direct peer (Typst-native, calm dark hero, modular)
- **Overleaf** — historical incumbent for the same job-to-be-done
- **Linear / Granola / distill.pub / Notion** — productivity & long-form
  reading peers with current-feeling design

It is **not** in the peer set with consumer SaaS, indie Framer templates,
Web3 landing pages, or meme-y dev tools. The page must read as
*trustworthy enough to commit a dissertation to* before it reads as cool.

## Goal

Move the page from "professional but quiet 2022" to "modern 2026" while
keeping it legible, fast, and credible to researchers.

The five high-leverage moves, in priority order:

1. Editorial type pair (display serif italic + grotesk)
2. Tighter, larger hero
3. One restrained accent color
4. Bento grid of real product screenshots (replace abstract feature icons)
5. Dark-mode polish

That's the whole redesign. Everything else is restraint.

## Aesthetic lane (and what's out of bounds)

### In bounds: modern-minimal / restrained-editorial

- Display-serif italic for emphasis (Instrument Serif / Newsreader / Source
  Serif 4) paired with the existing Inter grotesk
- Larger hero scale with tight tracking
- One additional accent token, used sparingly (never more than 2 places)
- Gradient applied **only** to the brand mark or hero CTA, never broadly
- Bento / asymmetric grid for proof sections
- Larger app-surface radii (0.75–1rem on bento cards and hero mock)
- IntersectionObserver fade-in reveals (already present)
- Optional: 10–20px scroll-linked parallax on the hero mock
- Polished dark mode (cooler base, vivid neutrals, high body contrast)
- Real product screenshots replacing abstract icons

### Out of bounds (do not propose by default)

| Pattern                              | Why not                                             |
| ------------------------------------ | --------------------------------------------------- |
| Marquee / ticker strips              | Reads "Web3 SaaS"; unserious for academic tool      |
| Rotated stickers, "🌱 beta" chips    | Wrong audience; users want "v1.0", not stickers     |
| Hard-offset brutalist shadows        | Brutalist signal; clashes with "papers"             |
| Magnetic cursor                      | Hurts trackpad/keyboard; gimmick                    |
| Hand-drawn doodles, marker scribbles | Same                                                |
| Slang microcopy ("lock in", "no cap")| Half the user base writes in academic register      |
| Y2K chrome / aqua / lens-flare       | Costume-y for a serious editor                      |
| Multiple competing accent colors     | Visual noise; pick one                              |
| Custom non-system cursors            | A11y regression                                     |
| Lenis / scroll-jacking               | Controversial for long-form; small visual gain      |
| Emoji as primary iconography         | Lucide / Simple Icons remain canonical              |

## Usability guardrails (non-negotiable)

These hold regardless of visual direction:

- Body text never below **14px**, body line-height never below **1.5**.
- Contrast: **≥ 4.5:1** on body text, **≥ 3:1** on UI elements; verify any
  new accent against both light and dark backgrounds.
- No scroll hijacking. No `scroll-snap` on marketing pages. No scrollytelling.
- Custom cursors → never. Preserve system cursor expectations.
- Every CTA reachable via keyboard; focus rings remain visible.
- `prefers-reduced-motion: reduce` collapses all reveals/parallax to instant
  (this is already wired up — keep it).
- Long-form sections (FAQ, pricing tiers) stay quiet — no decoration competing
  with comparison reading.
- Display fonts only on headings, never body.

## Concrete deltas

### 1. Type pair — biggest single lever

Add Instrument Serif to the existing Inter import in
`lib/typster_web/components/layouts/marketing.html.heex`:

```html
<link
  rel="stylesheet"
  href="https://fonts.googleapis.com/css2?family=Inter:wght@100..900&family=Instrument+Serif:ital@0;1&display=swap"
/>
```

Then style the existing `<em>` inside the hero `h1`
(`lib/typster_web/controllers/page_html/home.html.heex`) — the markup
already wraps `Typst` in `<em>`, so this is purely a CSS change in
`assets/css/app.css`:

```css
.mk-hero h1 em {
  font-family: 'Instrument Serif', 'Times New Roman', serif;
  font-style: italic;
  font-weight: 400;
  color: var(--mk-pri);
  letter-spacing: -0.01em;
}
```

Alternates if Instrument Serif feels too contemporary:

- **Newsreader** (Google) — softer, more academic
- **Source Serif 4** (Google) — most academic-coded
- **PP Editorial New** (paid) — most "current"

### 2. Hero scale

In `assets/css/app.css`, replace the existing hero clamp with:

```css
.mk-hero h1 {
  font-size: clamp(40px, 5.5vw, 76px);
  letter-spacing: -0.025em;
  line-height: 1.02;
}
```

Conservative bump — not 8vw "feral" sizing. The serif italic does the
visual work; the size just gives it room.

### 3. One accent, used twice

Keep `--mk-pri` indigo. Add **one** secondary token next to it in
`assets/css/app.css` (`:root` block around line 132):

```css
--mk-acc:    #c4b5fd;  /* muted lilac — option A */
--mk-acc:    #d4a574;  /* warm clay — option B  */
--mk-acc-h:  /* hover variant */;
```

Use it only in two places:

1. The "Most popular" pricing flag (`.mk-price-featured`)
2. A subtle highlight on one hero word *or* the brand mark gradient stop

Do not sprinkle. The restraint is the point.

### 4. Bento features grid with real screenshots

The current `.mk-feat-grid` is a uniform 3×2 of abstract icon cards.
Replace with an asymmetric 12-column grid showing **actual product
surfaces** (this is what typst.app, Linear, Granola all do):

```
┌─────────────────────────┬─────────┬─────────┐
│  Command palette ⌘K     │ Live    │ Export  │
│  (large screenshot)     │ preview │ formats │
├──────────┬──────────────┴─────────┴─────────┤
│ Math     │  PDF preview / diff               │
│ snippets │  (large screenshot)               │
└──────────┴───────────────────────────────────┘
```

This is also better marketing — you're showing the product instead of
describing features in the abstract.

Prerequisite: capture 4–6 clean product screenshots (light + dark) at
2× DPR. Crop tightly. Add a 1px hairline border using `--mk-bd` so they
sit on the page rather than float.

### 5. Radii bump

In `assets/css/app.css`:

```css
:root {
  --mk-r-sm: 0.5rem;   /* was 0.375 */
  --mk-r:    0.75rem;  /* was 0.5   */
  --mk-r-lg: 1rem;     /* new       */
}
```

Apply `--mk-r-lg` to:

- The hero mock container (`.mk-mock`)
- Bento cards (new `.mk-bento-card`)
- The CTA band container

Subtle — makes everything read more "app", less "doc page".

### 6. Dark-mode polish

Researchers writing late will live in dark mode. Make it the **more
striking** of the two themes:

```css
html[data-theme="dark"] { background-color: #0c0a14; } /* cooler base */
[data-theme="dark"] .mk-body { background-color: #0c0a14; }
```

Verify body contrast (`--mk-fg2` on `#0c0a14`) stays ≥ 4.5:1. If not,
nudge `--mk-fg2` to `#dcdce0`.

### 7. Subtle hero parallax (optional)

In `assets/js/app.js`, on scroll, transform the `.mk-art` container by
`translateY(scrollY * 0.06)` capped at `-40px`. Wrap in a
`prefers-reduced-motion` guard. ~15 lines. Skip if it feels janky on
the editor mock.

## What to leave alone

- **Section order** — hero → stats → how-it-works → features → keyboard →
  demo → use cases → pricing → FAQ → CTA → footer works fine.
- **The three-pane editor mock** — it's the proof point. No stickers on it.
- **Floating frosted nav** — already current; keep.
- **Brushed-silver `.mk-body::after` texture** — adds character without
  shouting. Keep.
- **`docs/landing-style.md`** structure — update tokens in place when the
  redesign lands; don't rewrite the doc preemptively.

## Implementation order

Each step is an independently shippable PR:

1. **Type pair + hero scale** (`app.css` + font link). Lowest risk,
   biggest perceived jump.
2. **Radii bump + accent token + dark-mode tone** (`app.css` only).
3. **Bento features grid** (markup + CSS in `home.html.heex` and
   `app.css`). Requires screenshots first.
4. **Optional hero parallax** (small JS).

Reassess after step 1 — it may already be enough.

## File map

| File                                                                | Role                                       |
| ------------------------------------------------------------------- | ------------------------------------------ |
| `assets/css/app.css` (lines ~132–200, then marketing block below)   | All `--mk-*` tokens, body texture, sections |
| `lib/typster_web/components/layouts/marketing.html.heex`            | Font imports, nav, theme script             |
| `lib/typster_web/controllers/page_html/home.html.heex`              | All landing sections                        |
| `assets/css/_typster_ui.css` + `_accent.css`                        | Product-UI `.ts-*` system + per-user accent |
| `assets/js/typst_highlight.js`                                      | Shiki-based Typst syntax highlighting       |
| `docs/landing-style.md`                                             | Source of truth (incl. "Product UI (`.ts-*`)") |
| `preview-export/index.html`                                         | Static snapshot for offline design review   |

> **Status:** the product UI (editor, projects, settings, auth) has been
> redesigned to carry this same DNA — floating `.mk-nav`, Instrument Serif
> accent, one restrained per-user accent, calm cards, polished dark mode — via
> the `.ts-*` system that aliases `--mk-*`. See the "Product UI (`.ts-*`)"
> section of `docs/landing-style.md`. Icons are heroicons (`<.icon>`) for app
> UI, `lucide` (`data-lucide` + `window.mkIcons`) for glyphs, and `simple-icons`
> for brand marks — there is no `<.mk_icon>` helper or `priv/static/images/icons/`.
