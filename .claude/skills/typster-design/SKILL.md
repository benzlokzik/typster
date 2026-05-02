---
name: typster-design
description: Design system, aesthetic direction, and copy voice guide for all Typster frontend work. Use this skill whenever the user is building, editing, reviewing, or extending any page or component in the Typster web app — landing page, app UI, marketing sections, new routes, or any .heex template or CSS. Also trigger when the user asks about tokens, copy, components, dark mode, animations, redesign direction, or wants to add a new section, page, or design pattern. When a new design decision is made, update the relevant guide doc to keep it current.
---

# Typster Design System

Two docs to read before any frontend work:

1. **`docs/landing-redesign-guide.md`** — the current aesthetic direction: what's in bounds, what's out of bounds, the five high-leverage moves, usability guardrails, and the concrete implementation deltas. This is the *why* and *what next*.
2. **`docs/landing-style.md`** — the source of truth for every existing token, component, layout rule, motion pattern, and icon. This is the *what exists now*.

When they conflict, the redesign guide wins — it represents intent, the style doc represents current state.

## Aesthetic lane (internalize this)

Typster is an academic/research tool. The peer set is typst.app, Overleaf, Linear, distill.pub — not consumer SaaS, not Framer templates, not Web3.

The page must read as *trustworthy enough to commit a dissertation to* before it reads as cool.

**In bounds:** display-serif italic + grotesk pairing, tight large hero, one restrained accent, bento grid with real product screenshots, larger radii, polished dark mode, scroll-reveal fades.

**Out of bounds** (never propose by default): marquee/ticker strips, rotated stickers, brutalist hard-offset shadows, magnetic cursor, hand-drawn doodles, slang microcopy ("lock in", "no cap"), Y2K chrome, multiple competing accents, custom cursors, Lenis/scroll-jacking, emoji as primary iconography.

## Hard rules

**CSS tokens only.** Every color, shadow, and radius lives in `app.css` as a `--mk-*` variable. Hardcoded values are wrong by default.

**Both themes, always.** Every new component must work in light *and* dark. New tokens get declared in both `:root` and `[data-theme="dark"]`. Dark mode is the more striking of the two — researchers write late.

**Reach for existing components first.** `.mk-btn`, `.mk-pill`, `.mk-feat`, `.mk-section`, and friends exist — extend before inventing. New components go into `app.css` under the `--mk-` namespace.

**No inline styles.** `style=""` is banned except for CSS custom property injection (e.g., `--i` stagger index on reveal groups).

**Reduced motion is not optional.** Every animation or transition needs a `@media (prefers-reduced-motion: reduce)` counterpart. It's already wired up — keep it that way.

**Usability floor:** body text ≥ 14px, line-height ≥ 1.5, contrast ≥ 4.5:1 on body text, ≥ 3:1 on UI elements. No scroll hijacking. Every CTA reachable by keyboard.

## Copy voice: zoomer-academic

Typster copy lives at the intersection of a citation style guide and a group chat. Precise enough to earn trust, loose enough to feel human.

- **Typster is a verb.** "Just Typster it." "You've been Typstering." Let the brand act, not just sit there.
- **Dry wit over hype.** No exclamation marks in body copy. Deadpan > cheerful.
- **Real terms, casual delivery.** Use the actual vocabulary — compile, typeset, LaTeX, diff — without the stiff formality. "compiles in ~200ms" not "renders documents with sub-200ms latency."
- **Sentence case everywhere.** Headlines, buttons, labels. All of it.
- **No corpo filler.** On sight: delete "seamlessly", "powerful", "intuitive", "robust", "world-class", "cutting-edge". Each one is a confession that you ran out of things to say.
- **Academic register, gen-z cadence.** Think: "the document compiles. you're cooked if it doesn't."

## Updating the guides

When a design decision extends or changes the system — new token, new component pattern, new copy rule, aesthetic shift — update the relevant doc:
- Changes to existing tokens/components → `docs/landing-style.md`
- Changes to direction, aesthetic rules, or what's in/out of bounds → `docs/landing-redesign-guide.md`

The docs must stay in sync with the codebase, not lag behind it.
