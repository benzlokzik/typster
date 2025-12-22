let worker = null
let previewContainer = null
let pushEvent = null

export function initTypstWorker(hook) {
  if (typeof Worker !== "undefined") {
    if (hook && typeof hook.pushEvent === "function") {
      pushEvent = hook.pushEvent.bind(hook)
    }

    previewContainer = hook ? hook.el : document.getElementById("preview-container")

    if (!worker) {
      worker = new Worker("/assets/js/typst_worker_impl.js", { type: "module" })

      worker.onmessage = (event) => {
        const { type, data } = event.data

        if (type === "render") {
          if (typeof pushEvent === "function") {
            pushEvent("update_preview", { svg: data.svg })
          }
        } else if (type === "error") {
          console.error("Typst compilation error:", data)
        }
      }

      worker.onerror = (error) => {
        console.error("Typst worker error:", error)
      }

      window.typstWorker = worker
    }

    return worker
  } else {
    console.warn("Web Workers are not supported in this browser")
    return null
  }
}

export function compileTypst(content) {
  if (!worker) {
    initTypstWorker(null)
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
    pushEvent = null
    window.typstWorker = null
  }
}
