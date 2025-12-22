import { updatePreview } from "./preview"

let worker = null
let previewContainer = null

export function initTypstWorker(hook) {
  if (typeof Worker !== "undefined") {
    previewContainer = hook ? hook.el : document.getElementById("preview-container")

    if (worker) {
      return worker
    }

    worker = new Worker("/assets/js/typst_worker_impl.js", { type: "module" })

    worker.onmessage = (event) => {
      const { type, data } = event.data

      if (type === "render") {
        if (previewContainer) {
          updatePreview(previewContainer, data.svg)
        }
      } else if (type === "error") {
        console.error("Typst compilation error:", data)
      }
    }

    worker.onerror = (error) => {
      console.error("Typst worker error:", error)
    }

    window.typstWorker = worker
    return worker
  } else {
    console.warn("Web Workers are not supported in this browser")
    return null
  }
}

export function compileTypst(content) {
  if (!previewContainer) {
    previewContainer = document.getElementById("preview-container")
  }

  if (!worker && previewContainer) {
    const hookEl = previewContainer
    const hook = hookEl.__liveSocketHook || null
    initTypstWorker({ el: hookEl, pushEvent: hook?.pushEvent })
  }

  if (worker && worker.readyState !== Worker.CLOSED) {
    worker.postMessage({
      type: "compile",
      content: content
    })
  } else if (!worker && previewContainer) {
    setTimeout(() => {
      if (worker && worker.readyState !== Worker.CLOSED) {
        worker.postMessage({
          type: "compile",
          content: content
        })
      }
    }, 100)
  }
}

export function destroyTypstWorker() {
  if (worker) {
    worker.terminate()
    worker = null
    previewContainer = null
    window.typstWorker = null
  }
}
