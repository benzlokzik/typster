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

async function ensureInitialized() {
  if (initialized) return
  initialized = true
  await $typst.svg({ mainContent: "" }).catch(() => {})
}

self.onmessage = async function (event) {
  const { type, content, project } = event.data

  if (type === "compile") {
    const myId = ++latestCompileId
    try {
      await ensureInitialized()
      if (myId !== latestCompileId) return

      $typst.setMainFilePath("/main.typ")
      await $typst.addSource("/main.typ", content || "")
      if (myId !== latestCompileId) return

      if (project?.sources) {
        for (const source of project.sources) {
          if (source.path !== "/main.typ" && source.path !== "main.typ") {
            await $typst.addSource(`/${source.path}`, source.content || "")
          }
        }
      }

      const svg = await $typst.svg({ mainFilePath: "/main.typ" })
      if (myId !== latestCompileId) return

      self.postMessage({ type: "render", data: { svg } })
    } catch (error) {
      if (myId !== latestCompileId) return
      self.postMessage({ type: "error", data: { message: error.message } })
    }
  }
}
