// CodeMirror 6 autocomplete source for the Typst language.
//
// Wired in editor.js via `autocompletion({ override: [typstCompletionSource] })`.
// This file owns the *data* only — it never imports `autocompletion` itself, so
// the editor keeps sole control over the extension and its keymap/config.
//
// Each entry is a plain object that is mapped to a CM `Completion`:
//   - `type`   drives the gutter icon: function | keyword | constant | type | variable
//   - `detail` is the dimmed signature shown to the right (this is the signature help)
//   - `info`   is a one-sentence description for the docs tooltip
//   - functions / structural keywords expand to a snippet (with the `#` marker
//     and a `(${})` / scaffold), so accepting one drops the caret into place.

import { snippetCompletion } from "@codemirror/autocomplete"

// ── Markup & layout functions ───────────────────────────────────────────────
// `sig` becomes `detail`; for functions we also synthesize `apply: "<name>("`.
const FUNCTIONS = [
  ["heading", "body, level, ..", "A section heading; level controls depth."],
  ["par", "body, leading, ..", "A logical paragraph with its own spacing."],
  ["text", "body, size, fill, ..", "Styled inline text run (size, font, fill, weight)."],
  ["strong", "body, delta", "Bold / strongly emphasized content."],
  ["emph", "body", "Emphasized (italic) content."],
  ["underline", "body, stroke, ..", "Underlines its content."],
  ["strike", "body, stroke, ..", "Strikes through its content."],
  ["overline", "body, stroke, ..", "Draws a line over its content."],
  ["highlight", "body, fill, ..", "Highlights content with a background fill."],
  ["sub", "body, typographic", "Renders content as subscript."],
  ["super", "body, typographic", "Renders content as superscript."],
  ["smallcaps", "body", "Renders text in small capitals."],
  ["raw", "text, lang, block, ..", "Raw / code text with optional syntax highlighting."],
  ["link", "dest, body", "A hyperlink to a URL or document location."],
  ["ref", "target, supplement", "A cross-reference to a label."],
  ["cite", "key, form, style", "A citation to a bibliography entry."],
  ["footnote", "body, numbering", "Attaches a footnote to the current position."],
  ["list", "..children, marker, ..", "An unordered (bullet) list."],
  ["enum", "..children, numbering, ..", "An ordered (numbered) list."],
  ["terms", "..children, separator, ..", "A term / description list."],
  ["table", "..children, columns, ..", "A table laid out in a grid of cells."],
  ["grid", "..children, columns, rows, ..", "A flexible grid layout of cells."],
  ["figure", "body, caption, ..", "A figure with an optional caption and label."],
  ["image", "source, format, width, ..", "Embeds a raster or vector image from a path."],
  ["box", "body, width, height, ..", "An inline-level container box."],
  ["block", "body, width, fill, ..", "A block-level container with spacing/fill."],
  ["stack", "..children, dir, spacing", "Stacks content along a direction."],
  ["columns", "body, count, gutter", "Lays content out in equal-width columns."],
  ["place", "body, alignment, dx, dy", "Places content out of flow at an offset."],
  ["align", "body, alignment", "Aligns content horizontally and/or vertically."],
  ["pad", "body, left, top, ..", "Adds padding around content."],
  ["move", "body, dx, dy", "Moves content without affecting layout."],
  ["scale", "body, x, y, origin", "Scales content around an origin."],
  ["rotate", "body, angle, origin", "Rotates content by an angle."],
  ["repeat", "body, gap, justify", "Repeats content to fill available space."],
  ["hide", "body", "Hides content while keeping its layout footprint."],
  ["rect", "body, width, height, ..", "Draws a rectangle, optionally with content."],
  ["square", "body, size, ..", "Draws a square, optionally with content."],
  ["circle", "body, radius, ..", "Draws a circle, optionally with content."],
  ["ellipse", "body, width, height, ..", "Draws an ellipse, optionally with content."],
  ["polygon", "..vertices, fill, stroke", "Draws a polygon from vertex points."],
  ["path", "..vertices, fill, stroke, ..", "Draws a Bezier path through points."],
  ["line", "start, end, length, ..", "Draws a straight line."],
  ["curve", "..components, fill, stroke", "Draws a curve from path components."],
  ["lorem", "words", "Generates that many words of placeholder text."],
  ["page", "body, width, margin, ..", "Configures the page geometry and content."],
  ["counter", "key", "Creates or references a counter by key."],
  ["numbering", "numbering, ..numbers", "Formats numbers with a numbering pattern."],
  ["label", "name", "Creates a label that can be referenced."],
  ["outline", "title, target, depth, ..", "A table of contents for the document."],
  ["bibliography", "sources, title, style, ..", "Renders a bibliography from sources."],
  ["document", "title, author, ..", "Sets document-wide metadata."],
  ["metadata", "value", "Attaches queryable metadata to the document."],
  ["datetime", "year, month, day, ..", "Constructs a date/time value."],
  ["measure", "content, ..", "Measures the layout size of content."],
  ["layout", "func", "Provides the available layout region to a callback."],
  ["context", "body", "Resolves context-dependent values at this point."],
  ["style", "func", "Accesses active styles via a callback."],
  ["query", "target, location", "Queries the document for matching elements."],
  ["pattern", "body, size, ..", "Defines a tiling pattern fill."],
  ["gradient", "..stops, ..", "Constructs a color gradient."]
]

// ── Spacing / break helpers (function-call style, but tiny signatures) ───────
const SPACING = [
  ["v", "amount, weak", "Inserts vertical spacing."],
  ["h", "amount, weak", "Inserts horizontal spacing."],
  ["parbreak", "", "Forces a paragraph break."],
  ["linebreak", "justify", "Forces a line break."],
  ["pagebreak", "weak, to", "Forces a page break."],
  ["colbreak", "weak", "Forces a column break."],
  ["smartquote", "double, enabled, ..", "Renders a smart (curly) quote."]
]

// ── Keywords / rules. These are typically written after `#` in markup. ───────
// `apply` strips the leading `#` so it only fires on the keyword token.
const KEYWORDS = [
  ["set", "set Elem(..)", "Set rule: configures default arguments of an element."],
  ["show", "show sel: it => ..", "Show rule: transforms how elements are displayed."],
  ["let", "let name = value", "Binds a value or defines a function."],
  ["import", 'import "mod": a, b', "Imports definitions from a module."],
  ["include", 'include "file.typ"', "Includes the content of another file."],
  ["if", "if cond { .. }", "Conditional branch."],
  ["else", "else { .. }", "Alternative branch of an if/else."],
  ["for", "for x in it { .. }", "Iterates over a collection."],
  ["in", "x in collection", "Membership / loop binding keyword."],
  ["while", "while cond { .. }", "Loops while a condition holds."],
  ["return", "return value", "Returns a value from a function."],
  ["break", "", "Breaks out of the current loop."],
  ["continue", "", "Skips to the next loop iteration."],
  ["as", 'import "m" as n', "Renames an import."]
]

// ── Constants / literals. ────────────────────────────────────────────────────
const CONSTANTS = [
  ["none", "none", "The empty / absent value."],
  ["auto", "auto", "Lets Typst choose the value automatically."],
  ["true", "true", "Boolean true."],
  ["false", "false", "Boolean false."]
]

// ── Built-in value types (for set rules, casts, annotations). ────────────────
const TYPES = [
  ["int", "int", "Integer number type."],
  ["float", "float", "Floating-point number type."],
  ["length", "length", "A size such as 2cm or 12pt."],
  ["ratio", "ratio", "A percentage such as 50%."],
  ["relative", "relative", "A length relative to a base, e.g. 2cm + 10%."],
  ["fraction", "fraction", "A fraction of remaining space, e.g. 1fr."],
  ["angle", "angle", "An angle such as 90deg or 1rad."],
  ["color", "color", "A color value."],
  ["str", "str", "A string of text."],
  ["bool", "bool", "A boolean value."],
  ["content", "content", "A piece of typeset content."],
  ["array", "array", "An ordered sequence of values."],
  ["dictionary", "dictionary", "A key/value mapping."],
  ["alignment", "alignment", "A horizontal/vertical alignment value."],
  ["direction", "direction", "A layout direction (ltr, rtl, ttb, btt)."],
  ["stroke", "stroke", "A line stroke style."]
]

// ── Common math symbols (relevant inside `$ .. $`). ──────────────────────────
const MATH = [
  ["sum", "∑", "Summation operator (large)."],
  ["product", "∏", "Product operator (large)."],
  ["integral", "∫", "Integral operator."],
  ["dif", "d", "Differential 'd' for derivatives/integrals."],
  ["alpha", "α", "Greek lowercase alpha."],
  ["beta", "β", "Greek lowercase beta."],
  ["gamma", "γ", "Greek lowercase gamma."],
  ["delta", "δ", "Greek lowercase delta."],
  ["theta", "θ", "Greek lowercase theta."],
  ["lambda", "λ", "Greek lowercase lambda."],
  ["mu", "μ", "Greek lowercase mu."],
  ["pi", "π", "Greek lowercase pi."],
  ["sigma", "σ", "Greek lowercase sigma."],
  ["phi", "φ", "Greek lowercase phi."],
  ["omega", "ω", "Greek lowercase omega."],
  ["infinity", "∞", "Infinity symbol (alias: oo)."],
  ["arrow.r", "→", "Rightwards arrow."],
  ["arrow.l", "←", "Leftwards arrow."],
  ["arrow.t", "↑", "Upwards arrow."],
  ["arrow.b", "↓", "Downwards arrow."],
  ["dot", "⋅", "Dot / multiplication operator."],
  ["times", "×", "Multiplication cross."],
  ["div", "÷", "Division sign."],
  ["plus.minus", "±", "Plus-minus sign."],
  ["eq", "=", "Equals relation."],
  ["eq.not", "≠", "Not-equal relation."],
  ["approx", "≈", "Approximately-equal relation."],
  ["lt", "<", "Less-than relation."],
  ["gt", ">", "Greater-than relation."],
  ["lt.eq", "≤", "Less-than-or-equal relation."],
  ["gt.eq", "≥", "Greater-than-or-equal relation."],
  ["in", "∈", "Element-of relation."],
  ["subset", "⊂", "Subset relation."],
  ["union", "∪", "Set union."],
  ["sect", "∩", "Set intersection."]
]

// Functions complete to "#name()" with the caret inside the parens. The "#" is
// part of the snippet; the source anchors `from` at the token start, so the
// marker is added when missing and never doubled when the user already typed it.
function fnOption([name, sig, info]) {
  return snippetCompletion("#" + name + "(${})", {
    label: "#" + name,
    type: "function",
    detail: sig,
    info
  })
}

// Structural keywords expand to a scaffold with the symbols they require.
const KEYWORD_SNIPPETS = {
  set: "#set ${}",
  show: "#show ${}",
  let: "#let ${name} = ${value}",
  import: '#import "${module}"',
  include: '#include "${file}"',
  if: "#if ${condition} [${}]",
  else: "else [${}]",
  for: "#for ${item} in ${collection} [${}]",
  while: "#while ${condition} [${}]",
  return: "#return ${}"
}

function kwOption([name, sig, info]) {
  const template = KEYWORD_SNIPPETS[name]

  if (template) {
    return snippetCompletion(template, {
      label: template[0] === "#" ? "#" + name : name,
      type: "keyword",
      detail: sig,
      info
    })
  }

  // Sub-keywords (in, as, break, continue) just insert their bare label.
  return { label: name, type: "keyword", detail: sig, info }
}

function plainOption(type) {
  return ([label, sig, info]) => ({ label, type, detail: sig, info })
}

// Single flat list consumed by the completion source.
export const TYPST_COMPLETIONS = [
  ...FUNCTIONS.map(fnOption),
  ...SPACING.map(fnOption),
  ...KEYWORDS.map(kwOption),
  ...CONSTANTS.map(plainOption("constant")),
  ...TYPES.map(plainOption("type")),
  ...MATH.map(plainOption("variable"))
]

// Local `#let` definitions in the current buffer, surfaced as completions so a
// user's own variables and functions are suggested alongside the built-ins.
// `#let f(..) = ..` completes to a call; a bare `#let x = ..` to the name.
// `boost: 50` ranks locals above the built-ins.
const LET_RE = /#let\s+([A-Za-z_][\w-]*)\s*(\([^)]*\))?\s*=/g

export function localCompletions(state) {
  const text = state.doc.toString()
  const seen = new Set()
  const out = []
  LET_RE.lastIndex = 0

  let m
  while ((m = LET_RE.exec(text))) {
    const name = m[1]
    if (seen.has(name)) continue
    seen.add(name)

    if (m[2]) {
      out.push(
        snippetCompletion("#" + name + "(${})", {
          label: "#" + name,
          type: "function",
          detail: m[2].slice(1, -1) || "..",
          info: "Local function",
          boost: 50
        })
      )
    } else {
      out.push({
        label: "#" + name,
        type: "variable",
        detail: "local",
        info: "Local variable",
        boost: 50
      })
    }
  }

  return out
}

// Symbols pulled in by `#import` statements in the current buffer, e.g.
// `#import "@preview/cetz:0.2.0": canvas, draw` or `#import "u.typ" as u`.
// Explicit names complete to a call (most imports are functions); an `as` alias
// is offered as a module handle. Wildcards (`: *`) can't be enumerated without
// the module source, so they're skipped.
const IMPORT_RE = /#import\s+(?:"[^"]*"|[\w@/.:-]+)\s*(?::\s*([^\n]+)|\bas\s+([A-Za-z_][\w-]*))/g

export function importedCompletions(state) {
  const text = state.doc.toString()
  const seen = new Set()
  const out = []
  IMPORT_RE.lastIndex = 0

  let m
  while ((m = IMPORT_RE.exec(text))) {
    if (m[2]) {
      const alias = m[2]
      if (seen.has(alias)) continue
      seen.add(alias)
      out.push({
        label: "#" + alias,
        type: "namespace",
        detail: "module",
        info: "Imported module",
        boost: 40
      })
      continue
    }

    for (const part of m[1].split(",")) {
      const as = /\bas\s+([A-Za-z_][\w-]*)/.exec(part)
      const name = as ? as[1] : part.trim().replace(/[^\w-].*$/, "")
      if (!name || !/^[A-Za-z_]/.test(name) || seen.has(name)) continue
      seen.add(name)
      out.push(
        snippetCompletion("#" + name + "(${})", {
          label: "#" + name,
          type: "function",
          detail: "imported",
          info: "Imported symbol",
          boost: 40
        })
      )
    }
  }

  return out
}

// A valid CM6 `CompletionSource`. Anchors `from` at the token start (including
// any leading #/@) so snippet labels like "#figure" match and replace cleanly,
// adding the marker when it is missing. Auto-opens only after a #/@ marker —
// Typst's escape into code — so it never pops while writing prose; everything
// is still reachable on an explicit invoke (Ctrl-Space).
export function typstCompletionSource(context) {
  const word = context.matchBefore(/[#@]?[\w.-]*/)
  if (!word) return null

  const marked = word.text[0] === "#" || word.text[0] === "@"
  if (!marked && !context.explicit) return null
  if (word.from === word.to && !context.explicit) return null

  return {
    from: word.from,
    options: TYPST_COMPLETIONS.concat(
      localCompletions(context.state),
      importedCompletions(context.state)
    ),
    validFor: /^[#@]?[\w.-]*$/
  }
}
