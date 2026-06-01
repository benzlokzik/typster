// Editor v3.1 assists, built from the same granular @codemirror/* packages as
// editor.js so the EditorView / decoration facets share one instance set.
//
//   • inline diagnostic lens — the full compile message under the bad line
//   • scroll rail            — error / warning / heading marks on the right edge
//   • selection bubble       — floating quick-actions over a non-empty selection
//
// All three read live data already flowing through the editor: diagnostics come
// from the Typst worker (see editor.js `setDiagnostics`), headings from the doc.
import { EditorView, Decoration, WidgetType, ViewPlugin, showTooltip } from "@codemirror/view"
import { StateField, StateEffect } from "@codemirror/state"

// ── Shared diagnostics data (drives both the lens and the rail) ──────────────
// Carries already-resolved CodeMirror diagnostics ({from, to, severity, message}).
export const setDiagData = StateEffect.define()

export const diagDataField = StateField.define({
  create: () => [],
  update(value, tr) {
    for (const e of tr.effects) if (e.is(setDiagData)) return e.value
    return value
  }
})

// Push resolved diagnostics into the editor state (called from editor.js).
export function applyDiagData(view, cmDiagnostics) {
  view.dispatch({ effects: setDiagData.of(cmDiagnostics || []) })
}

// ── Inline diagnostic lens ───────────────────────────────────────────────────
class DiagLensWidget extends WidgetType {
  constructor(severity, message) {
    super()
    this.severity = severity === "warning" ? "warning" : "error"
    this.message = message
  }
  eq(other) {
    return other.severity === this.severity && other.message === this.message
  }
  toDOM() {
    const wrap = document.createElement("div")
    wrap.className = `cm-diag-lens is-${this.severity}`

    const ico = document.createElement("span")
    ico.className = "cm-diag-lens__ico"
    ico.setAttribute("aria-hidden", "true")
    ico.textContent = this.severity === "warning" ? "▲" : "✕"

    const body = document.createElement("div")
    body.className = "cm-diag-lens__body"

    const title = document.createElement("div")
    title.className = "cm-diag-lens__title"
    title.textContent = this.message

    const code = document.createElement("span")
    code.className = "cm-diag-lens__code"
    code.textContent = this.severity === "warning" ? "warning" : "error"

    body.appendChild(title)
    wrap.appendChild(ico)
    wrap.appendChild(body)
    wrap.appendChild(code)
    return wrap
  }
  ignoreEvent() {
    return true
  }
}

function lensDecorations(state) {
  const diags = state.field(diagDataField, false) || []
  const doc = state.doc
  const seen = new Set()
  const deco = []
  for (const d of diags) {
    const line = doc.lineAt(Math.min(Math.max(d.from, 0), doc.length))
    if (seen.has(line.from)) continue
    seen.add(line.from)
    deco.push(
      Decoration.widget({
        widget: new DiagLensWidget(d.severity, d.message),
        block: true,
        side: 1
      }).range(line.to)
    )
  }
  deco.sort((a, b) => a.from - b.from)
  return Decoration.set(deco)
}

// A StateField (not a ViewPlugin) so the block widgets are accounted for in
// height measurement.
export const inlineDiagnostics = StateField.define({
  create: (state) => lensDecorations(state),
  update(value, tr) {
    if (tr.docChanged || tr.effects.some((e) => e.is(setDiagData))) {
      return lensDecorations(tr.state)
    }
    return value.map(tr.changes)
  },
  provide: (f) => EditorView.decorations.from(f)
})

// ── Scroll rail (right-edge minimap of marks) ────────────────────────────────
const HEADING_RE = /^\s*(?:=+|#+)\s+\S/

export const scrollRail = ViewPlugin.fromClass(
  class {
    constructor(view) {
      this.rail = document.createElement("div")
      this.rail.className = "cm-rail"
      this.rail.setAttribute("aria-hidden", "true")
      view.dom.appendChild(this.rail)
      this.render(view)
    }
    update(u) {
      const diagChanged = u.state.field(diagDataField, false) !== u.startState.field(diagDataField, false)
      if (u.docChanged || u.geometryChanged || diagChanged) this.render(u.view)
    }
    render(view) {
      const doc = view.state.doc
      const total = Math.max(doc.lines, 1)
      const marks = []

      const diags = view.state.field(diagDataField, false) || []
      for (const d of diags) {
        const ln = doc.lineAt(Math.min(Math.max(d.from, 0), doc.length)).number
        marks.push({ line: ln, kind: d.severity === "warning" ? "warning" : "error" })
      }
      for (let i = 1; i <= doc.lines; i++) {
        if (HEADING_RE.test(doc.line(i).text)) marks.push({ line: i, kind: "heading" })
      }

      this.rail.replaceChildren()
      for (const m of marks) {
        const el = document.createElement("div")
        el.className = `cm-rail__mark is-${m.kind}`
        el.style.top = `${(((m.line - 0.5) / total) * 100).toFixed(3)}%`
        this.rail.appendChild(el)
      }
    }
    destroy() {
      this.rail.remove()
    }
  }
)

// ── Selection quick-action bubble ────────────────────────────────────────────
// Buttons re-use the existing editor command pipeline (the CodeMirror hook
// listens for `phx:editor-command` and calls runEditorCommand on the selection).
const BUBBLE_ACTIONS = [
  { cmd: "heading", label: "= Heading", primary: true, title: "Wrap as heading" },
  { cmd: "bold", label: "B", title: "Bold (⌘B)" },
  { cmd: "italic", label: "I", title: "Italic (⌘I)" },
  { cmd: "math", label: "∑", title: "Inline math" },
  { sep: true },
  { cmd: "link", label: "Link", title: "Wrap as link" }
]

function bubbleTooltip(from) {
  return {
    pos: from,
    above: true,
    strictSide: false,
    arrow: false,
    create: () => {
      const dom = document.createElement("div")
      dom.className = "cm-qa"
      for (const a of BUBBLE_ACTIONS) {
        if (a.sep) {
          const s = document.createElement("span")
          s.className = "cm-qa__sep"
          dom.appendChild(s)
          continue
        }
        const b = document.createElement("button")
        b.type = "button"
        b.className = "cm-qa__btn" + (a.primary ? " is-primary" : "")
        b.textContent = a.label
        b.title = a.title
        // mousedown + preventDefault keeps the selection alive for the command.
        b.addEventListener("mousedown", (e) => {
          e.preventDefault()
          window.dispatchEvent(new CustomEvent("phx:editor-command", { detail: { cmd: a.cmd } }))
        })
        dom.appendChild(b)
      }
      return { dom }
    }
  }
}

export const selectionBubble = StateField.define({
  create: () => null,
  update(value, tr) {
    const sel = tr.state.selection.main
    if (sel.empty || sel.to - sel.from > 5000) return null
    return bubbleTooltip(sel.from)
  },
  provide: (f) => showTooltip.from(f)
})

// Everything the editor needs, in dependency order (diagDataField first).
export const editorV3Extensions = [
  diagDataField,
  inlineDiagnostics,
  scrollRail,
  selectionBubble
]
