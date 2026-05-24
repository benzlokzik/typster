import { EditorView, basicSetup } from "codemirror"
import { EditorState, Compartment } from "@codemirror/state"
import { StreamLanguage } from "@codemirror/language"
import { typst } from "./typst_syntax"
import { markdown } from "@codemirror/lang-markdown"
import { yaml } from "@codemirror/lang-yaml"
import { stex } from "@codemirror/legacy-modes/mode/stex"
import { compileTypst } from "./typst_worker"

function getCurrentTheme() {
  const html = document.documentElement
  const theme = html.getAttribute("data-theme")
  if (theme === "dark") return "dark"
  if (theme === "light") return "light"
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
  return prefersDark ? "dark" : "light"
}

const lightTheme = EditorView.theme({
  "&": {
    backgroundColor: "#ffffff",
    color: "#09090b",
    fontSize: "14px",
    fontFamily: "'JetBrains Mono', 'Fira Code', ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"
  },
  ".cm-content": {
    padding: "16px",
    minHeight: "100%",
    lineHeight: "1.6"
  },
  ".cm-focused": { outline: "none" },
  ".cm-editor": { height: "100%" },
  ".cm-scroller": {
    fontFamily: "'JetBrains Mono', 'Fira Code', ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"
  },
  ".cm-gutters": { backgroundColor: "#f4f4f5", color: "#a1a1aa", border: "none" },
  ".cm-lineNumbers .cm-gutterElement": { minWidth: "3ch", padding: "0 8px 0 16px" },
  ".cm-activeLine": { backgroundColor: "#fafafa" },
  ".cm-activeLineGutter": { backgroundColor: "#fafafa", color: "#09090b" },
  ".cm-selectionMatch": { backgroundColor: "rgba(79, 70, 229, 0.2)" },
  "&.cm-focused .cm-selectionBackground": { backgroundColor: "rgba(79, 70, 229, 0.2)" },
  ".cm-cursor": { borderLeftColor: "#09090b" },
  ".cm-selectionBackground": { backgroundColor: "rgba(79, 70, 229, 0.2)" }
})

const darkTheme = EditorView.theme({
  "&": {
    backgroundColor: "#09090b",
    color: "#fafafa",
    fontSize: "14px",
    fontFamily: "'JetBrains Mono', 'Fira Code', ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"
  },
  ".cm-content": {
    padding: "16px",
    minHeight: "100%",
    lineHeight: "1.6"
  },
  ".cm-focused": { outline: "none" },
  ".cm-editor": { height: "100%" },
  ".cm-scroller": {
    fontFamily: "'JetBrains Mono', 'Fira Code', ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, 'Liberation Mono', monospace"
  },
  ".cm-gutters": { backgroundColor: "#18181b", color: "#71717a", border: "none" },
  ".cm-lineNumbers .cm-gutterElement": { minWidth: "3ch", padding: "0 8px 0 16px" },
  ".cm-activeLine": { backgroundColor: "#27272a" },
  ".cm-activeLineGutter": { backgroundColor: "#27272a", color: "#fafafa" },
  ".cm-selectionMatch": { backgroundColor: "rgba(99, 102, 241, 0.2)" },
  "&.cm-focused .cm-selectionBackground": { backgroundColor: "rgba(99, 102, 241, 0.2)" },
  ".cm-cursor": { borderLeftColor: "#fafafa" },
  ".cm-selectionBackground": { backgroundColor: "rgba(99, 102, 241, 0.2)" }
})

function getThemeExtension() {
  return getCurrentTheme() === "dark" ? darkTheme : lightTheme
}

// ── Formatting commands ─────────────────────────────────────────────────────
// Markers are language-aware: Typst uses *bold* _italic_, Markdown uses
// **bold** *italic*. Everything funnels through `runCommand`.
const MARKERS = {
  typst: {
    bold: ["*", "*"],
    italic: ["_", "_"],
    math: ["$ ", " $"],
    heading: { line: "= " },
    list: { line: "- " },
    link: { snippet: '#link("https://")[text]', placeholder: "text" },
    image: { snippet: '#image("image.png")' },
    table: { snippet: "#table(\n  columns: 2,\n  [a], [b],\n)" }
  },
  markdown: {
    bold: ["**", "**"],
    italic: ["*", "*"],
    math: ["$", "$"],
    heading: { line: "# " },
    list: { line: "- " },
    link: { snippet: "[text](https://)", placeholder: "text" },
    image: { snippet: "![](image.png)" },
    table: { snippet: "| a | b |\n| --- | --- |\n| 1 | 2 |" }
  }
}

function markersFor(language) {
  return MARKERS[language] || MARKERS.typst
}

function wrapSelection(view, before, after) {
  const { from, to } = view.state.selection.main
  const selected = view.state.sliceDoc(from, to)
  view.dispatch({
    changes: { from, to, insert: `${before}${selected}${after}` },
    selection: { anchor: from + before.length, head: from + before.length + selected.length }
  })
  view.focus()
}

function prefixLine(view, prefix) {
  const line = view.state.doc.lineAt(view.state.selection.main.head)
  view.dispatch({
    changes: { from: line.from, insert: prefix },
    selection: { anchor: view.state.selection.main.head + prefix.length }
  })
  view.focus()
}

function insertSnippet(view, snippet, placeholder) {
  const { from, to } = view.state.selection.main
  view.dispatch({ changes: { from, to, insert: snippet } })

  if (placeholder) {
    const idx = snippet.indexOf(placeholder)
    if (idx >= 0) {
      view.dispatch({
        selection: { anchor: from + idx, head: from + idx + placeholder.length }
      })
    }
  }
  view.focus()
}

function gotoLine(view, lineNumber) {
  const total = view.state.doc.lines
  const n = Math.min(Math.max(parseInt(lineNumber, 10) || 1, 1), total)
  const line = view.state.doc.line(n)
  view.dispatch({ selection: { anchor: line.from }, scrollIntoView: true })
  view.focus()
}

function runEditorCommand(view, language, cmd, arg = {}) {
  const m = markersFor(language)
  switch (cmd) {
    case "bold":
    case "italic":
    case "math":
      wrapSelection(view, m[cmd][0], m[cmd][1])
      break
    case "heading":
    case "list":
      prefixLine(view, m[cmd].line)
      break
    case "link":
    case "image":
    case "table":
      insertSnippet(view, m[cmd].snippet, m[cmd].placeholder)
      break
    case "goto":
      gotoLine(view, arg.line)
      break
    default:
      break
  }
}

// Parse headings into an outline. Typst headings start with `=`, Markdown `#`.
function parseOutline(content, language) {
  const re = language === "markdown" ? /^(#{1,6})\s+(.+?)\s*$/ : /^(={1,6})\s+(.+?)\s*$/
  const items = []
  content.split("\n").forEach((text, i) => {
    const match = re.exec(text)
    if (match) {
      items.push({
        level: Math.min(match[1].length, 3),
        text: match[2].replace(/[*_`]/g, ""),
        line: i + 1
      })
    }
  })
  return items
}

function cursorPosition(state) {
  const head = state.selection.main.head
  const line = state.doc.lineAt(head)
  return { line: line.number, col: head - line.from + 1 }
}

function getLanguageExtension(lang) {
  switch (lang) {
    case "typst":    return typst()
    case "markdown": return markdown()
    case "yaml":     return yaml()
    case "latex":
    case "tex":      return StreamLanguage.define(stex)
    default:         return []
  }
}

export function initEditor(container, initialContent, socket, fileId, options = {}) {
  let autosaveTimer = null
  let compileTimer = null
  let outlineTimer = null
  let lastOutline = ""
  const themeCompartment = new Compartment()
  const languageCompartment = new Compartment()
  const language = options.language || "typst"
  const onCursor = typeof options.onCursor === "function" ? options.onCursor : null
  const onOutline = typeof options.onOutline === "function" ? options.onOutline : null

  const emitOutline = (content) => {
    if (!onOutline) return
    const items = parseOutline(content, language)
    const signature = JSON.stringify(items)
    if (signature !== lastOutline) {
      lastOutline = signature
      onOutline(items)
    }
  }

  const updateListener = EditorView.updateListener.of((update) => {
    if (onCursor && (update.docChanged || update.selectionSet)) {
      const { line, col } = cursorPosition(update.state)
      onCursor(line, col)
    }

    if (update.docChanged) {
      clearTimeout(autosaveTimer)

      const content = update.state.doc.toString()

      if (fileId && socket) {
        socket.pushEvent("save_started", {})
        autosaveTimer = setTimeout(() => {
          socket.pushEvent("autosave", {
            file_id: fileId,
            content: content
          })
        }, 500)
      }

      if (language === "typst") {
        clearTimeout(compileTimer)
        compileTimer = setTimeout(() => {
          if (socket) socket.pushEvent("compile_started", {})
          compileTypst(content, options.project || {})
        }, 300)
      }

      clearTimeout(outlineTimer)
      outlineTimer = setTimeout(() => emitOutline(content), 400)
    }
  })

  const state = EditorState.create({
    doc: initialContent || "",
    extensions: [
      basicSetup,
      themeCompartment.of(getThemeExtension()),
      languageCompartment.of(getLanguageExtension(language)),
      updateListener
    ]
  })

  const editor = new EditorView({
    state: state,
    parent: container
  })

  if (initialContent && language === "typst") {
    compileTypst(initialContent, options.project || {})
  }

  // Seed cursor + outline from the initial document.
  if (onCursor) {
    const { line, col } = cursorPosition(editor.state)
    onCursor(line, col)
  }
  emitOutline(initialContent || "")

  const updateTheme = () => {
    editor.dispatch({
      effects: themeCompartment.reconfigure(getThemeExtension())
    })
  }

  const updateLanguage = (newLang) => {
    editor.dispatch({
      effects: languageCompartment.reconfigure(getLanguageExtension(newLang))
    })
  }

  return {
    editor,
    updateTheme,
    updateLanguage,
    runCommand: (cmd, arg) => runEditorCommand(editor, language, cmd, arg),
    compile: () => compileTypst(editor.state.doc.toString(), options.project || {}),
    destroy: () => {
      if (autosaveTimer) clearTimeout(autosaveTimer)
      if (compileTimer) clearTimeout(compileTimer)
      if (outlineTimer) clearTimeout(outlineTimer)
      editor.destroy()
    }
  }
}

export function updateEditorContent(editorInstance, content) {
  if (editorInstance && editorInstance.editor) {
    const currentContent = editorInstance.editor.state.doc.toString()
    if (currentContent !== content) {
      editorInstance.editor.dispatch({
        changes: {
          from: 0,
          to: editorInstance.editor.state.doc.length,
          insert: content
        }
      })
    }
  }
}

export function destroyEditor(editorInstance) {
  if (editorInstance && editorInstance.destroy) {
    editorInstance.destroy()
  }
}
