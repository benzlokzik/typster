self.onmessage = function(event) {
  const { type, content } = event.data

  if (type === "compile") {
    try {
      const placeholderSvg = `
        <svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
          <rect width="800" height="600" fill="white"/>
          <text x="400" y="300" text-anchor="middle" font-family="Arial" font-size="16" fill="black">
            Typst compilation will appear here
          </text>
          <text x="400" y="330" text-anchor="middle" font-family="Arial" font-size="12" fill="gray">
            (Typst WASM integration pending)
          </text>
        </svg>
      `

      self.postMessage({
        type: "render",
        data: {
          svg: placeholderSvg
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
