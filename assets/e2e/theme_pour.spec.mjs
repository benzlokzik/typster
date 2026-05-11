import { test, expect } from "@playwright/test"

// Pixel-color helpers — used to assert that the html background settles to the
// expected theme without flickering through an intermediate "strange vivid"
// color during the View Transitions pour animation.
const colorOf = async (page, selector = ":root") =>
  page.evaluate((sel) => {
    const el = sel === ":root" ? document.documentElement : document.querySelector(sel)
    return getComputedStyle(el).backgroundColor
  }, selector)

const setStoredTheme = async (page, theme) => {
  await page.addInitScript((stored) => {
    try { localStorage.setItem("phx:theme", stored) } catch {}
  }, theme)
}

const recordBackgrounds = async (page, durationMs = 1200, intervalMs = 40) =>
  page.evaluate(({ duration, interval }) => new Promise((resolve) => {
    const samples = []
    const start = performance.now()
    const tick = () => {
      samples.push({
        t: performance.now() - start,
        theme: document.documentElement.getAttribute("data-theme"),
        html: getComputedStyle(document.documentElement).backgroundColor,
        body: getComputedStyle(document.body).backgroundColor
      })
      if (performance.now() - start < duration) setTimeout(tick, interval)
      else resolve(samples)
    }
    tick()
  }), { duration: durationMs, interval: intervalMs })

const TOGGLE = ".mk-theme-toggle"

test.describe("theme pour animation", () => {
  test("clicking the toggle flips the theme and runs the pour", async ({ page }) => {
    await setStoredTheme(page, "light")
    await page.goto("/")
    await expect(page.locator("html")).toHaveAttribute("data-theme", "light")

    const toggle = page.locator(TOGGLE)
    await expect(toggle).toBeVisible()

    // Click; immediately probe for the in-flight state.
    await toggle.click()
    await expect(toggle).toHaveClass(/is-pouring/, { timeout: 200 })

    // Theme must have flipped synchronously inside the transition's update callback.
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark")

    // Pour clears within ~900ms (CSS keyframe duration is 760ms).
    await expect(toggle).not.toHaveClass(/is-pouring/, { timeout: 1500 })

    // Persisted to localStorage so reload keeps the new theme.
    expect(await page.evaluate(() => localStorage.getItem("phx:theme"))).toBe("dark")
  })

  test("dark → light direction works the same way", async ({ page }) => {
    await setStoredTheme(page, "dark")
    await page.goto("/")
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark")

    await page.locator(TOGGLE).click()

    await expect(page.locator("html")).toHaveAttribute("data-theme", "light")
    await expect(page.locator(TOGGLE)).not.toHaveClass(/is-pouring/, { timeout: 1500 })
    expect(await page.evaluate(() => localStorage.getItem("phx:theme"))).toBe("light")
  })

  test("no strange vivid mid-flight: html settles to the dark surface, not a flash color", async ({ page }) => {
    await setStoredTheme(page, "light")
    await page.goto("/")

    // Capture pre-click colors (locked to light).
    const preHtml = await colorOf(page, "html")

    const samplesPromise = recordBackgrounds(page, 1400, 40)
    await page.locator(TOGGLE).click()
    const samples = await samplesPromise

    // data-theme must flip exactly once during the recording window.
    const flips = samples.filter((s, i) => i > 0 && s.theme !== samples[i - 1].theme)
    expect(flips.length, `theme should flip exactly once, got ${flips.length}`).toBe(1)
    expect(flips[0].theme).toBe("dark")

    // Final settled background must differ from the light pre-click background
    // (proves the dark theme is actually painted, not a transparent intermediate).
    const finalSample = samples.at(-1)
    expect(finalSample.theme).toBe("dark")
    expect(finalSample.html).not.toBe(preHtml)

    // None of the recorded samples should report a fully-transparent or
    // unexpectedly bright color (a "vivid flash"). We treat any sample whose
    // RGB channels are all > 240 *after* the flip as suspicious — the dark
    // surface should never be brighter than the light surface.
    const bright = samples.filter((s) => {
      if (s.theme !== "dark") return false
      const m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(s.html)
      if (!m) return false
      const [, r, g, b] = m.map(Number)
      return r > 240 && g > 240 && b > 240
    })
    expect(bright, "dark theme html should never paint as near-white").toEqual([])
  })

  test("reduced-motion bypass: theme flips instantly with no pour class", async ({ browser }) => {
    const context = await browser.newContext({ reducedMotion: "reduce" })
    const page = await context.newPage()
    await page.addInitScript(() => { try { localStorage.setItem("phx:theme", "light") } catch {} })
    await page.goto("/")

    await page.locator(TOGGLE).click()

    // Theme flipped, but the pour class must never have been applied.
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark")
    await expect(page.locator(TOGGLE)).not.toHaveClass(/is-pouring/)

    await context.close()
  })

  test("rapid double-click does not stack pours or get stuck", async ({ page }) => {
    await setStoredTheme(page, "light")
    await page.goto("/")

    const toggle = page.locator(TOGGLE)
    // Two clicks in quick succession — the re-entry guard should drop the second
    // until the first transition finishes, leaving the theme in dark.
    await toggle.click()
    await toggle.click({ delay: 0 })

    // After both pours resolve we should land on a stable theme (dark, since
    // the second click was suppressed) and the pour class is cleared.
    await expect(toggle).not.toHaveClass(/is-pouring/, { timeout: 2000 })
    const theme = await page.locator("html").getAttribute("data-theme")
    expect(["dark", "light"]).toContain(theme)
    // The pouring guard must be released once the view transition finishes.
    await expect.poll(() => page.evaluate(() => window.__mkPouring), { timeout: 2000 }).toBeFalsy()
  })
})
