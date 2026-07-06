// Standalone bootstrap for the public embed page (/embed/:token).
//
// The embed is framed on third-party sites, where the SameSite=Lax session
// cookie is blocked — so a LiveView socket can never establish and the client
// would reload-loop. Instead the embed page renders statically and we boot the
// read-only editor + WASM preview here, directly, with NO socket. Everything it
// needs (content, language, project sources, theme) is in the DOM dataset.

import { initEditor } from "./editor"
import { initTypstWorker, compileTypst } from "./typst_worker"

function parseJsonDataset(value, fallback) {
  if (!value) return fallback
  try {
    return JSON.parse(value)
  } catch (_error) {
    return fallback
  }
}

function editorOptions(el) {
  return {
    language: el.dataset.language || "typst",
    readonly: el.dataset.readonly === "true",
    project: {
      // Real path of the entry file so subdirectory imports resolve (see hooks.js).
      mainPath: el.dataset.fileName || "",
      sources: parseJsonDataset(el.dataset.projectSources, []),
      assets: parseJsonDataset(el.dataset.projectAssets, []),
    },
  }
}

// A no-op stand-in for a LiveView hook: the embed has no server to push to, so
// outline/cursor/compile-stat callbacks simply go nowhere. Rendering (CodeMirror
// DOM, the compiled SVG) is all client-side and does not need the socket.
const NOOP_HOOK = { pushEvent() {}, pushEventTo() {}, handleEvent() {}, el: null }

// Returns true when it booted an embed page (so the caller skips liveSocket).
export function bootEmbed() {
  const embed = document.getElementById("typster-embed")
  if (!embed) return false

  // `?theme=light|dark` is rendered onto the embed wrapper, but CodeMirror's
  // theme extension keys off the document root (which the layout bootstrap
  // derives from this origin's localStorage — empty inside a visitor's
  // iframe). Mirror the forced theme up so the editor matches the chrome.
  const forcedTheme = embed.dataset.theme
  if (forcedTheme === "light" || forcedTheme === "dark") {
    document.documentElement.setAttribute("data-theme", forcedTheme)
  }

  const ec = document.getElementById("editor-container")
  let content = ""
  let project = { sources: [], assets: [] }
  let language = "typst"

  if (ec) {
    content = ec.dataset.content || ""
    language = ec.dataset.language || "typst"
    const options = { ...editorOptions(ec), onCursor() {}, onOutline() {} }
    project = options.project
    initEditor(ec, content, NOOP_HOOK, ec.dataset.fileId || null, options)
  }

  // initTypstWorker reads its target from `hook.el`, so the stub must carry the
  // real preview element (a null `el` would silently drop every rendered frame).
  const previewEl = document.getElementById("preview-container")
  if (previewEl) {
    initTypstWorker({ ...NOOP_HOOK, el: previewEl })
    if (content && language === "typst") {
      setTimeout(() => compileTypst(content, project), 100)
    }
  }

  return true
}
