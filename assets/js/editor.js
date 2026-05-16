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
  const themeCompartment = new Compartment()
  const languageCompartment = new Compartment()
  const language = options.language || "typst"

  const updateListener = EditorView.updateListener.of((update) => {
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
        compileTimer = setTimeout(() => compileTypst(content, options.project || {}), 300)
      }
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
    destroy: () => {
      if (autosaveTimer) clearTimeout(autosaveTimer)
      if (compileTimer) clearTimeout(compileTimer)
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
