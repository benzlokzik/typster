self.onmessage = function(event) {
  const { type, content, project } = event.data

  if (type === "compile") {
    try {
      const sourceCount = project && Array.isArray(project.sources) ? project.sources.length : 0
      const assetCount = project && Array.isArray(project.assets) ? project.assets.length : 0

      self.postMessage({
        type: "render",
        data: {
          sourceCount,
          assetCount
        }
      })
    } catch (error) {
      self.postMessage({
        type: "error",
        data: {
          message: error.message
        }
      })
    }
  }
}

export {}
