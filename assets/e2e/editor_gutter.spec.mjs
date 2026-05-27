import { test, expect } from "@playwright/test"

// Opens a fresh project's editor with an empty main.typ ready for typing.
async function openEditor(page, name) {
  await page.goto("/projects")
  await page.waitForFunction(() => window.liveSocket?.isConnected?.(), null, { timeout: 10_000 })
  await page.locator("#new-project-button").click()
  await page.locator('.ts-dialog input[name="name"]').fill(name)
  await page.locator('.ts-dialog button[type="submit"]').click()
  const row = page.locator(".ts-list__row").filter({ hasText: name })
  await row.getByRole("link", { name: "Open" }).click()
  await page.locator("#create-main-file-button").click()
  const draft = page.locator('#new-file-form input[name="path"]')
  await draft.fill("main.typ")
  await draft.press("Enter")
  const cm = page.locator("#editor-container .cm-content")
  await cm.click({ timeout: 10_000 })
  return cm
}

const firstGutter = (page) => page.locator(".cm-lineNumbers .cm-gutterElement").first()
const gutterWidth = (page) => firstGutter(page).evaluate((el) => el.getBoundingClientRect().width)

test.describe("Editor line-number gutter", () => {
  test("line numbers are right-aligned", async ({ page }) => {
    await openEditor(page, `Gutter Align ${Date.now()}`)
    await page.keyboard.type("alpha\nbeta\ngamma")

    await expect(firstGutter(page)).toHaveCSS("text-align", "right")
  })

  test("reserves room for 5 digits and holds steady up to 99999", async ({ page }) => {
    const cm = await openEditor(page, `Gutter Reserve ${Date.now()}`)
    await page.keyboard.type("one\ntwo\nthree")
    await page.waitForTimeout(150)

    // Width of a single monospace digit in the gutter, measured live.
    const digit = await page.evaluate(() => {
      const el = document.querySelector(".cm-lineNumbers .cm-gutterElement")
      const cs = getComputedStyle(el)
      const probe = document.createElement("span")
      probe.textContent = "0"
      probe.style.fontFamily = cs.fontFamily
      probe.style.fontSize = cs.fontSize
      probe.style.position = "absolute"
      probe.style.visibility = "hidden"
      document.body.appendChild(probe)
      const w = probe.getBoundingClientRect().width
      probe.remove()
      return w
    })

    // Floor must fit 5 digits even though only single-digit numbers are shown.
    const reserve = await gutterWidth(page)
    expect(reserve).toBeGreaterThanOrEqual(5 * digit)

    // Grow to 3-digit line numbers; the reserve must not shift, and numbers must
    // not clip. (Past 99999 CM widens the gutter natively — min-width is a floor,
    // not a cap — which is impractical to exercise with real keystrokes.)
    await cm.click()
    await page.keyboard.type("\n".repeat(140))
    await page.waitForTimeout(200)

    const maxDigits = await page.evaluate(() =>
      Math.max(
        ...[...document.querySelectorAll(".cm-lineNumbers .cm-gutterElement")].map(
          (el) => (el.textContent || "").trim().length
        )
      )
    )
    expect(maxDigits).toBeGreaterThanOrEqual(3)

    const after = await gutterWidth(page)
    expect(Math.abs(after - reserve)).toBeLessThanOrEqual(1)

    const clipped = await page.evaluate(() =>
      [...document.querySelectorAll(".cm-lineNumbers .cm-gutterElement")].some(
        (el) => el.scrollWidth > el.clientWidth + 1
      )
    )
    expect(clipped).toBe(false)
  })

  test("selection uses the native browser selection, not a drawSelection layer", async ({
    page
  }) => {
    const cm = await openEditor(page, `Gutter Selection ${Date.now()}`)
    await page.keyboard.type("alpha line one\nbeta")

    // No CodeMirror selection layer should exist (drawSelection removed).
    await expect(page.locator(".cm-selectionLayer")).toHaveCount(0)

    await page.keyboard.press(process.platform === "darwin" ? "Meta+a" : "Control+a")
    const selected = await page.evaluate(() => window.getSelection().toString())
    expect(selected).toContain("alpha line one")
    await cm.click() // collapse
  })

  test("marks every selected newline incl. blank lines, sized to the selection", async ({
    page
  }) => {
    await openEditor(page, `Gutter EOL ${Date.now()}`)
    const mod = process.platform === "darwin" ? "Meta" : "Control"
    await page.keyboard.press(`${mod}+a`) // clear the seeded starter content
    await page.keyboard.press("Backspace")
    await page.keyboard.type("first line\n\nthird line") // line 2 is blank

    // Select all: the newline after line 1 (text) and line 2 (blank) are in the
    // selection → a marker on each; line 3 is last (no trailing newline) → none.
    await page.keyboard.press(`${mod}+a`)
    await expect(page.locator(".cm-eol-mark")).toHaveCount(2)

    // Each marker is painted by an inline background, so it matches the native
    // selection band's height pixel-for-pixel (≤1px), not the full line height.
    const cmp = await page.evaluate(() => {
      const selH = [...window.getSelection().getRangeAt(0).getClientRects()][0].height
      const marks = [...document.querySelectorAll(".cm-eol-mark")].map((m) => {
        const r = m.getBoundingClientRect()
        return { w: r.width, h: r.height }
      })
      return { selH, marks }
    })
    for (const m of cmp.marks) {
      expect(m.w).toBeGreaterThan(0)
      expect(Math.abs(m.h - cmp.selH)).toBeLessThanOrEqual(1)
    }

    // The marker is selection-only: collapsing the selection removes it.
    await page.keyboard.press("ArrowRight")
    await expect(page.locator(".cm-eol-mark")).toHaveCount(0)
  })

  test("a selected text-line newline also gets a marker (VS Code parity)", async ({ page }) => {
    await openEditor(page, `Gutter EOL Text ${Date.now()}`)
    const mod = process.platform === "darwin" ? "Meta" : "Control"
    await page.keyboard.press(`${mod}+a`) // clear the seeded starter content
    await page.keyboard.press("Backspace")
    await page.keyboard.type("alpha\nbeta") // two text lines, no blank line

    // Newline after line 1 (a text line) is selected → it gets a marker too;
    // line 2 is last (no trailing newline) → none.
    await page.keyboard.press(`${mod}+a`)
    await expect(page.locator(".cm-eol-mark")).toHaveCount(1)
  })

  test("end-of-line marker does not change line height (no reflow)", async ({ page }) => {
    await openEditor(page, `Gutter Reflow ${Date.now()}`)
    // Include a blank line — that's the case that grows when the marker is
    // in-flow, since a blank line has no text to anchor the line box.
    await page.keyboard.type("alpha\n\ngamma\ndelta")
    await page.waitForTimeout(150)

    const contentH = () =>
      page.evaluate(() => document.querySelector(".cm-content").getBoundingClientRect().height)

    const before = await contentH()
    // Select everything → eol markers appear on every line but the last.
    await page.keyboard.press(process.platform === "darwin" ? "Meta+a" : "Control+a")
    await expect(page.locator(".cm-eol-mark").first()).toBeAttached()
    const during = await contentH()

    // Out-of-flow markers must not grow the document (the bug grew a blank line
    // by a full row); allow sub-pixel rounding only.
    expect(Math.abs(during - before)).toBeLessThanOrEqual(1)
  })
})
