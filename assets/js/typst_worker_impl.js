import { setImportWasmModule as setCompilerWasmModule } from "@myriaddreamin/typst-ts-web-compiler"
import { setImportWasmModule as setRendererWasmModule } from "@myriaddreamin/typst-ts-renderer"
import { $typst } from "@myriaddreamin/typst.ts/contrib/snippet"

// Both the compiler and renderer have independent WASM loaders that throw by default.
// Override both to fetch from the known static path instead of relying on import.meta.url,
// which breaks in bundled worker contexts (Chrome: "Cannot import wasm module without importer").
const wasmLoader = async (wasmName) => {
  const response = await fetch(`/assets/js/${wasmName}`)
  if (!response.ok) throw new Error(`Failed to fetch ${wasmName}: ${response.status}`)
  return response.arrayBuffer()
}
setCompilerWasmModule(wasmLoader)
setRendererWasmModule(wasmLoader)

let initialized = false
let latestCompileId = 0

// typst.ts doesn't always throw a standard Error — a compile failure may surface
// as a plain string (the formatted diagnostic), an array of diagnostics, or an
// object. Coerce any of these into readable text so the message is never lost.
function formatError(error) {
  if (error == null) return "Typst preview failed"
  if (typeof error === "string") return error

  if (Array.isArray(error)) {
    const parts = error.map(formatError).filter(Boolean)
    if (parts.length) return parts.join("\n")
  }

  if (typeof error.message === "string" && error.message) return error.message

  if (typeof error.toString === "function") {
    const str = error.toString()
    if (str && str !== "[object Object]") return str
  }

  try {
    const json = JSON.stringify(error)
    if (json && json !== "{}") return json
  } catch (_ignored) {
    // fall through
  }

  return "Typst preview failed"
}

// `diagnostics: 'full'` returns DiagnosticMessage objects:
//   { package, path: "/main.typ", severity, range: "2:9-3:15", message }
// Turn them into structured items the preview can render directly (clean path,
// numeric line/col), rather than re-parsing formatted text.
function structureDiagnostics(diagnostics) {
  if (!Array.isArray(diagnostics) || diagnostics.length === 0) return null

  return diagnostics.map((d) => {
    const file = String((d && d.path) || "").replace(/^\/+/, "") || null
    const severity = String((d && d.severity) || "error").toLowerCase().includes("warn")
      ? "warning"
      : "error"
    // range is "line:col" or "line:col-endline:endcol" (1-based).
    const m = String((d && d.range) || "").match(/(\d+):(\d+)(?:-(\d+):(\d+))?/)
    const location = file
      ? {
          file,
          line: m ? Number(m[1]) : null,
          col: m ? Number(m[2]) : null,
          endLine: m && m[3] ? Number(m[3]) : null,
          endCol: m && m[4] ? Number(m[4]) : null
        }
      : null

    return { severity, location, message: (d && d.message) || "Compilation error" }
  })
}

async function ensureInitialized() {
  if (initialized) return
  initialized = true
  await $typst.svg({ mainContent: "" }).catch(() => {})
}

async function loadSources(content, project) {
  $typst.setMainFilePath("/main.typ")
  await $typst.addSource("/main.typ", content || "")

  if (project?.sources) {
    for (const source of project.sources) {
      if (source.path !== "/main.typ" && source.path !== "main.typ") {
        await $typst.addSource(`/${source.path}`, source.content || "")
      }
    }
  }
}

self.onmessage = async function (event) {
  const { type, content, project, requestId } = event.data

  if (type === "compile") {
    const myId = ++latestCompileId
    try {
      await ensureInitialized()
      if (myId !== latestCompileId) return

      await loadSources(content, project)
      if (myId !== latestCompileId) return

      const svg = await $typst.svg({ mainFilePath: "/main.typ" })
      if (myId !== latestCompileId) return

      self.postMessage({ type: "render", data: { svg } })
    } catch (error) {
      if (myId !== latestCompileId) return
      console.error("typst compile failed (raw):", error)

      // The high-level svg() suppresses diagnostics, so the caught error is
      // opaque. Recompile once with full diagnostics to recover the real
      // error text (sources are re-mapped first in case state was reset).
      let structured = null
      try {
        await loadSources(content, project)
        const compiler = await $typst.getCompiler()
        const { diagnostics } = await compiler.compile({
          mainFilePath: "/main.typ",
          diagnostics: "full"
        })
        structured = structureDiagnostics(diagnostics)
      } catch (diagError) {
        console.error("typst diagnostics recompile failed:", diagError)
      }

      const message = (structured && structured[0] && structured[0].message) || formatError(error)
      self.postMessage({ type: "error", data: { message, diagnostics: structured } })
    }
  } else if (type === "pdf") {
    // Export bypasses latestCompileId: a download is an explicit one-off and must
    // not be cancelled by a concurrent live-preview compile.
    try {
      await ensureInitialized()
      await loadSources(content, project)

      const pdf = await $typst.pdf({ mainFilePath: "/main.typ" })
      self.postMessage({ type: "pdf", data: { pdf, requestId } }, [pdf.buffer])
    } catch (error) {
      self.postMessage({ type: "pdf-error", data: { message: formatError(error), requestId } })
    }
  }
}
