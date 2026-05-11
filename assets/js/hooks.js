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
  mounted() {
    const container = this.el
    const rawContent = this.el.dataset.content || ""
    const content = parseContent(rawContent)
    const fileId = this.el.dataset.fileId || null
    const options = editorOptions(this.el)

    if (!container) return

    this.previousFileId = fileId

    this.editorInstance = initEditor(
      container,
      content,
      this.liveSocket || window.liveSocket,
      fileId,
      options
    )

    this.handleEvent("content_updated", ({ content }) => {
      if (this.editorInstance) {
        updateEditorContent(this.editorInstance, content)
      }
    })

    this.handleEvent("file_changed", ({ file_id, content, language }) => {
      const newFileId = file_id || null
      const newContent = parseContent(content || "")
      const options = editorOptions(this.el)
      options.language = language || options.language

      if (this.previousFileId !== newFileId) {
        this.previousFileId = newFileId
        this.cleanupThemeHandlers()
        if (this.editorInstance) {
          destroyEditor(this.editorInstance)
        }
        this.editorInstance = initEditor(
          container,
          newContent,
          this.liveSocket || window.liveSocket,
          newFileId,
          options
        )
        this.setupThemeHandlers()
      } else if (this.editorInstance) {
        updateEditorContent(this.editorInstance, newContent)
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

  updated() {
    const rawContent = this.el.dataset.content || ""
    const newContent = parseContent(rawContent)
    const newFileId = this.el.dataset.fileId || null
    const options = editorOptions(this.el)

    if (this.previousFileId === undefined) {
      this.previousFileId = newFileId
    }

    if (this.editorInstance) {
      if (this.previousFileId !== newFileId) {
        this.previousFileId = newFileId
        this.cleanupThemeHandlers()
        destroyEditor(this.editorInstance)
        const container = this.el
        this.editorInstance = initEditor(
          container,
          newContent,
          this.liveSocket || window.liveSocket,
          newFileId,
          options
        )
        this.setupThemeHandlers()
      } else {
        updateEditorContent(this.editorInstance, newContent)
      }
    } else if (newFileId) {
      this.previousFileId = newFileId
      this.cleanupThemeHandlers()
      const container = this.el
      this.editorInstance = initEditor(
        container,
        newContent,
        this.liveSocket || window.liveSocket,
        newFileId,
        options
      )
      this.setupThemeHandlers()
    }
  },

  destroyed() {
    this.cleanupThemeHandlers()
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
  updated() {
    const status = this.el.textContent.trim()
    if (status === "saved") {
      this.el.classList.remove("text-error")
      this.el.classList.add("text-success")
    } else if (status === "error") {
      this.el.classList.remove("text-success")
      this.el.classList.add("text-error")
    }
  }
}
