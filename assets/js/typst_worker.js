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
          if (previewContainer && data.svg) {
            const errEl = previewContainer.querySelector("#preview-error")
            if (errEl) errEl.style.display = "none"

            let svgContainer = previewContainer.querySelector("#typst-svg-output")
            if (!svgContainer) {
              svgContainer = document.createElement("div")
              svgContainer.id = "typst-svg-output"
              svgContainer.style.cssText = "width:100%;overflow:auto;"
              previewContainer.appendChild(svgContainer)
            }
            svgContainer.style.display = ""

            const placeholder = previewContainer.querySelector("#preview-placeholder")
            if (placeholder) placeholder.style.display = "none"

            svgContainer.innerHTML = data.svg
          }
        } else if (type === "error") {
          if (previewContainer) {
            let errEl = previewContainer.querySelector("#preview-error")
            if (!errEl) {
              errEl = document.createElement("div")
              errEl.id = "preview-error"
              errEl.className = "ts-card"
              errEl.style.cssText = "border-color:var(--mk-error-bd);background:var(--mk-error-50);color:var(--mk-error);padding:16px;font-size:13px;font-family:'JetBrains Mono',monospace;width:100%;max-width:520px;"
              previewContainer.appendChild(errEl)
            }
            errEl.textContent = data.message || "Typst preview failed"
            errEl.style.display = ""

            const svgContainer = previewContainer.querySelector("#typst-svg-output")
            if (svgContainer) svgContainer.style.display = "none"

            const placeholder = previewContainer.querySelector("#preview-placeholder")
            if (placeholder) placeholder.style.display = "none"
          }
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

export function compileTypst(content, project = {}) {
  if (!worker) {
    const container = document.getElementById("preview-container")
    if (container) {
      const hook = container.__liveSocketHook || null
      if (hook && typeof hook.pushEvent === "function") {
        initTypstWorker(hook)
      } else {
        initTypstWorker(null)
      }
    } else {
      initTypstWorker(null)
    }
  }

  if (!pushEvent && previewContainer) {
    const hook = previewContainer.__liveSocketHook || null
    if (hook && typeof hook.pushEvent === "function") {
      pushEvent = hook.pushEvent.bind(hook)
    }
  }

  if (worker) {
    worker.postMessage({
      type: "compile",
      content: content,
      project: project
    })
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
