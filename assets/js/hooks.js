import { initEditor, updateEditorContent, destroyEditor } from "./editor"
import { initTypstWorker, destroyTypstWorker, compileTypst } from "./typst_worker"

function parseContent(content) {
  return content || ""
}

function parseJsonDataset(value, fallback) {
  if (!value) return fallback
  try {
    return JSON.parse(value)
  } catch (_error) {
    return fallback
  }
}

function editorOptions(element) {
  return {
    language: element.dataset.language || "typst",
    project: {
      sources: parseJsonDataset(element.dataset.projectSources, []),
      assets: parseJsonDataset(element.dataset.projectAssets, [])
    }
  }
}

export const CodeMirror = {
  editorCallbacks() {
    return {
      onCursor: (line, col) => {
        const el = document.getElementById("status-cursor")
        if (el) el.textContent = `Ln ${line}, Col ${col}`
      },
      onOutline: (items) => {
        this.pushEvent("outline_parsed", { items })
      }
    }
  },

  setupCommandHandler() {
    this.commandHandler = (event) => {
      if (!this.editorInstance) return
      const { cmd, line } = event.detail || {}
      if (cmd === "compile") {
        this.editorInstance.compile()
      } else if (cmd === "download") {
        this.editorInstance.download()
      } else if (cmd === "search") {
        this.editorInstance.openSearch()
      } else if (cmd) {
        this.editorInstance.runCommand(cmd, { line })
      }
    }
    window.addEventListener("phx:editor-command", this.commandHandler)

    // The Typst worker emits diagnostics for the compiled buffer (reported as
    // "main.typ"); highlight those in the active editor and clear on success.
    this.diagnosticsHandler = (event) => {
      if (!this.editorInstance) return
      const all = (event.detail && event.detail.diagnostics) || []
      const own = all.filter((d) => {
        const file = d.location && d.location.file
        return !file || file === "main.typ"
      })
      this.editorInstance.setDiagnostics(own)
    }
    window.addEventListener("typst:diagnostics", this.diagnosticsHandler)
  },

  mounted() {
    const container = this.el
    const rawContent = this.el.dataset.content || ""
    const content = parseContent(rawContent)
    const fileId = this.el.dataset.fileId || null
    const options = { ...editorOptions(this.el), ...this.editorCallbacks() }

    if (!container) return

    this.previousFileId = fileId
    this.setupCommandHandler()

    if (fileId) {
      this.editorInstance = initEditor(
        container,
        content,
        this,
        fileId,
        options
      )
    }

    this.handleEvent("content_updated", ({ content }) => {
      if (this.editorInstance) {
        updateEditorContent(this.editorInstance, content)
      }
    })

    this.handleEvent("file_changed", ({ file_id, content, language }) => {
      const newFileId = file_id || null
      const newContent = parseContent(content || "")
      const options = { ...editorOptions(this.el), ...this.editorCallbacks() }
      options.language = language || options.language

      this.el.style.display = newFileId ? "" : "none"

      if (this.previousFileId !== newFileId) {
        this.previousFileId = newFileId
        this.cleanupThemeHandlers()
        if (this.editorInstance) {
          destroyEditor(this.editorInstance)
          this.editorInstance = null
        }
        if (newFileId) {
          this.editorInstance = initEditor(
            container,
            newContent,
            this,
            newFileId,
            options
          )
          this.setupThemeHandlers()
        }
      } else if (this.editorInstance) {
        updateEditorContent(this.editorInstance, newContent)
        if (language && this.editorInstance.updateLanguage) {
          this.editorInstance.updateLanguage(language)
        }
      }
    })

    this.themeChangeHandler = () => {
      if (this.editorInstance && this.editorInstance.updateTheme) {
        this.editorInstance.updateTheme()
      }
    }

    window.addEventListener("phx:set-theme", this.themeChangeHandler)

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === "attributes" && mutation.attributeName === "data-theme") {
          if (this.editorInstance && this.editorInstance.updateTheme) {
            this.editorInstance.updateTheme()
          }
        }
      })
    })

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })

    this.themeObserver = observer
  },

  setupThemeHandlers() {
    this.themeChangeHandler = () => {
      if (this.editorInstance && this.editorInstance.updateTheme) {
        this.editorInstance.updateTheme()
      }
    }

    window.addEventListener("phx:set-theme", this.themeChangeHandler)

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === "attributes" && mutation.attributeName === "data-theme") {
          if (this.editorInstance && this.editorInstance.updateTheme) {
            this.editorInstance.updateTheme()
          }
        }
      })
    })

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })

    this.themeObserver = observer
  },

  cleanupThemeHandlers() {
    if (this.themeChangeHandler) {
      window.removeEventListener("phx:set-theme", this.themeChangeHandler)
      this.themeChangeHandler = null
    }
    if (this.themeObserver) {
      this.themeObserver.disconnect()
      this.themeObserver = null
    }
  },

  updated() {},

  destroyed() {
    this.cleanupThemeHandlers()
    if (this.commandHandler) {
      window.removeEventListener("phx:editor-command", this.commandHandler)
      this.commandHandler = null
    }
    if (this.diagnosticsHandler) {
      window.removeEventListener("typst:diagnostics", this.diagnosticsHandler)
      this.diagnosticsHandler = null
    }
    if (this.editorInstance) {
      destroyEditor(this.editorInstance)
      this.editorInstance = null
    }
  }
}

export const Preview = {
  mounted() {
    initTypstWorker(this)

    const editorContainer = document.getElementById("editor-container")
    if (editorContainer) {
      const rawContent = editorContainer.dataset.content || ""
      const content = parseContent(rawContent)
      const language = editorContainer.dataset.language || "typst"
      const project = editorOptions(editorContainer).project
      if (content && language === "typst") {
        setTimeout(() => compileTypst(content, project), 100)
      }
    }
  },

  updated() {
    if (this.pushEvent) {
      initTypstWorker(this)
    }
  },

  destroyed() {
    destroyTypstWorker()
  }
}

export const SaveStatus = {
  updated() {}
}

// Editor shell: captures ⌘K / Ctrl+K to open the command palette, and
// re-initializes lucide icons after LiveView patches (the format toolbar and
// palette render <i data-lucide> nodes that need svg upgrading on each patch).
export const CommandPalette = {
  mounted() {
    if (window.mkIcons) window.mkIcons(this.el)

    this.keyHandler = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault()
        this.pushEvent("open_palette", {})
      }
    }
    window.addEventListener("keydown", this.keyHandler)
  },

  updated() {
    if (window.mkIcons) window.mkIcons(this.el)
  },

  destroyed() {
    if (this.keyHandler) window.removeEventListener("keydown", this.keyHandler)
  }
}

// Focus a search input when "/" is pressed outside of any text field.
export const SlashFocus = {
  mounted() {
    this.handler = (event) => {
      const tag = document.activeElement && document.activeElement.tagName
      if (event.key === "/" && tag !== "INPUT" && tag !== "TEXTAREA") {
        event.preventDefault()
        this.el.focus()
      }
    }
    window.addEventListener("keydown", this.handler)
  },

  destroyed() {
    if (this.handler) window.removeEventListener("keydown", this.handler)
  }
}

// Command palette keyboard navigation. Mounted only while the palette is open;
// owns active-item highlighting and Enter-to-activate (clicks the focused row,
// triggering whatever phx-click / JS.dispatch it carries).
export const Palette = {
  items() {
    return Array.from(this.el.querySelectorAll(".ts-palette__item"))
  },

  setActive(idx) {
    const items = this.items()
    if (!items.length) return
    this.active = (idx + items.length) % items.length
    items.forEach((el, i) => el.classList.toggle("is-active", i === this.active))
    items[this.active].scrollIntoView({ block: "nearest" })
  },

  mounted() {
    if (window.mkIcons) window.mkIcons(this.el)
    this.active = 0
    this.setActive(0)

    const input = this.el.querySelector("#palette-input")
    if (input) input.focus()

    this.keyHandler = (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault()
        this.setActive(this.active + 1)
      } else if (event.key === "ArrowUp") {
        event.preventDefault()
        this.setActive(this.active - 1)
      } else if (event.key === "Enter") {
        const items = this.items()
        if (items[this.active]) {
          event.preventDefault()
          items[this.active].click()
        }
      }
    }
    this.el.addEventListener("keydown", this.keyHandler)
  },

  updated() {
    if (window.mkIcons) window.mkIcons(this.el)
    this.setActive(this.active || 0)
  },

  destroyed() {
    if (this.keyHandler) this.el.removeEventListener("keydown", this.keyHandler)
  }
}

// Client-side zoom for the rendered Typst SVG. Owns its own DOM
// (phx-update="ignore") so LiveView patches to the preview bar don't reset it.
export const PreviewZoom = {
  mounted() {
    this.zoom = 100
    this.label = this.el.querySelector("#zoom-level")

    this.apply = () => {
      const svg = document.querySelector("#typst-svg-output")
      if (svg) {
        svg.style.transformOrigin = "top center"
        svg.style.transform = `scale(${this.zoom / 100})`
      }
      if (this.label) this.label.textContent = `${this.zoom}%`
    }

    this.clickHandler = (event) => {
      const button = event.target.closest("[data-zoom]")
      if (!button) return
      const dir = button.dataset.zoom
      if (dir === "in") this.zoom = Math.min(this.zoom + 10, 300)
      else if (dir === "out") this.zoom = Math.max(this.zoom - 10, 30)
      else this.zoom = 100
      this.apply()
    }

    this.el.addEventListener("click", this.clickHandler)
  },

  destroyed() {
    if (this.clickHandler) this.el.removeEventListener("click", this.clickHandler)
  }
}

// Re-render lucide `<i data-lucide>` icons inside a container that LiveView
// patches (the file tree and tab bar). The global mkIcons() only runs on full
// page loads, so without this, icons inside diffed regions would not paint.
export const LucideIcons = {
  mounted() { window.mkIcons?.(this.el) },
  updated() { window.mkIcons?.(this.el) }
}
