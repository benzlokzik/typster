import { test, expect } from "@playwright/test"

// Regression guard for #121: the preview worker used to flatten the active
// buffer to the project root ("/main.typ"), so a `.typ` file living in a
// subdirectory lost its directory and a relative `#import "sibling.typ"` failed
// with "failed to load file (access denied) … outside of project root".
//
// We drive the real worker the same way the editor does (postMessage a compile
// job) and assert the rendered/errored outcome — no DB or login required.
test.describe("Typst local imports", () => {
  async function compile(page, project, content) {
    return page.evaluate(
      ([project, content]) =>
        new Promise((resolve) => {
          const worker = new Worker("/assets/js/typst_worker_impl.js", { type: "module" })
          let timer
          const done = (value) => {
            clearTimeout(timer)
            worker.terminate()
            resolve(value)
          }
          timer = setTimeout(() => done({ ok: false, message: "timeout" }), 40_000)
          worker.onmessage = (event) => {
            const { type, data } = event.data
            if (type === "render") done({ ok: true })
            else if (type === "error") done({ ok: false, message: (data && data.message) || "error" })
          }
          worker.onerror = (err) => done({ ok: false, message: String(err.message || err) })
          worker.postMessage({ type: "compile", content, project })
        }),
      [project, content]
    )
  }

  test.beforeEach(async ({ page }) => {
    await page.goto("/")
  })

  test("a subdirectory file resolves a relative import to its sibling", async ({ page }) => {
    test.setTimeout(60_000)
    const buffer = '#import "macros.typ": foo\n#foo()'
    const result = await compile(
      page,
      {
        mainPath: "chapters/ch1.typ",
        sources: [
          { path: "chapters/ch1.typ", content: buffer },
          { path: "chapters/macros.typ", content: "#let foo() = [from macros]" }
        ]
      },
      buffer
    )
    expect(result).toEqual({ ok: true })
  })

  test("a flat root import still compiles with the default entrypoint", async ({ page }) => {
    test.setTimeout(60_000)
    const result = await compile(
      page,
      { sources: [{ path: "utils.typ", content: "#let hi() = [hi]" }] },
      '#import "utils.typ": hi\n#hi()'
    )
    expect(result).toEqual({ ok: true })
  })
})
