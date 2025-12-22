let worker = null
let previewHook = null

export function initTypstWorker(hook) {
  if (typeof Worker !== "undefined") {
    previewHook = hook

    if (worker) {
      return worker
    }

    worker = new Worker("/assets/js/typst_worker_impl.js", { type: "module" })

    worker.onmessage = (event) => {
      const { type, data } = event.data

      if (type === "render") {
        if (previewHook && previewHook.pushEvent) {
          previewHook.pushEvent("update_preview", {
            svg: data.svg
          })
        } else if (window.liveSocket) {
          const view = document.querySelector("[data-phx-view]")
          if (view) {
            const viewId = view.getAttribute("data-phx-view")
            if (viewId) {
              window.liveSocket.pushEventTo(viewId, "update_preview", {
                svg: data.svg
              })
            }
          }
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
  if (worker && worker.readyState !== Worker.CLOSED) {
    worker.postMessage({
      type: "compile",
      content: content
    })
  } else if (!worker && previewHook) {
    initTypstWorker(previewHook)
    if (worker) {
      setTimeout(() => {
        worker.postMessage({
          type: "compile",
          content: content
        })
      }, 100)
    }
  }
}

export function destroyTypstWorker() {
  if (worker) {
    worker.terminate()
    worker = null
    previewHook = null
    window.typstWorker = null
  }
}
