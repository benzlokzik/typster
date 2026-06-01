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
//   - functions get an `apply` that inserts an opening paren, so the cursor lands
//     inside the call; everything else inserts its bare label (no snippets).

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

function fnOption([label, sig, info]) {
  return {
    label,
    type: "function",
    detail: sig,
    info,
    // Insert the opening paren so the caret lands inside the argument list.
    apply: `${label}(`
  }
}

function plainOption(type) {
  return ([label, sig, info]) => ({ label, type, detail: sig, info })
}

// Single flat list consumed by the completion source.
export const TYPST_COMPLETIONS = [
  ...FUNCTIONS.map(fnOption),
  ...SPACING.map(fnOption),
  ...KEYWORDS.map(plainOption("keyword")),
  ...CONSTANTS.map(plainOption("constant")),
  ...TYPES.map(plainOption("type")),
  ...MATH.map(plainOption("variable"))
]

// A valid CM6 `CompletionSource`. Returns null when there is nothing to
// complete (empty token and not explicitly triggered), otherwise a result
// anchored at the start of the current word token.
export function typstCompletionSource(context) {
  // Match an optional #/@ call-or-ref marker plus the identifier being typed.
  const word = context.matchBefore(/[#@]?[\w.-]*/)
  if (!word || (word.from === word.to && !context.explicit)) return null

  // Anchor completion AFTER the marker so the typed text ("figu") filters
  // against bare labels ("figure") and apply leaves the marker in place
  // (e.g. "#figu" → "#figure(").
  const hasMarker = word.text[0] === "#" || word.text[0] === "@"

  return {
    from: hasMarker ? word.from + 1 : word.from,
    options: TYPST_COMPLETIONS,
    validFor: /^[\w.-]*$/
  }
}
