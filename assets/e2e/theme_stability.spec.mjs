import { test, expect } from "@playwright/test"

const stabilityMs = Number(process.env.THEME_STABILITY_MS || 7_000)

const readThemeState = async (page) =>
  page.evaluate(() => ({
    theme: document.documentElement.getAttribute("data-theme"),
    colorScheme: getComputedStyle(document.documentElement).colorScheme,
    htmlBackground: getComputedStyle(document.documentElement).backgroundColor,
    bodyBackground: getComputedStyle(document.body).backgroundColor
  }))

const installThemeRecorder = async (page, theme) => {
  await page.addInitScript((storedTheme) => {
    window.__themeChanges = []
    window.__recordThemeChange = (source) => {
      window.__themeChanges.push({
        source,
        theme: document.documentElement.getAttribute("data-theme"),
        at: performance.now()
      })
    }

    localStorage.setItem("phx:theme", storedTheme)

    new MutationObserver((mutations) => {
      if (mutations.some((mutation) => mutation.attributeName === "data-theme")) {
        window.__recordThemeChange("mutation")
      }
    }).observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"]
    })
  }, theme)
}

const expectStoredThemeToStayStable = async (page, theme) => {
  await installThemeRecorder(page, theme)
  await page.goto("/")

  await expect
    .poll(() => page.evaluate(() => document.documentElement.getAttribute("data-theme")))
    .toBe(theme)

  const initial = await readThemeState(page)

  await page.waitForTimeout(stabilityMs)

  const final = await readThemeState(page)
  const changes = await page.evaluate(() => window.__themeChanges)

  expect(final).toEqual(initial)
  expect(changes.every((change) => change.theme === theme)).toBe(true)
}

test.describe("theme stability", () => {
  test("saved dark theme does not switch by itself", async ({ page }) => {
    await expectStoredThemeToStayStable(page, "dark")
  })

  test("saved light theme does not switch by itself", async ({ page }) => {
    await expectStoredThemeToStayStable(page, "light")
  })
})
