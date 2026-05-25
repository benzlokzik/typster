import { test, expect } from '@playwright/test'

// Regression guard: switching language used to flash the chosen locale for a
// moment and then revert to the original once the LiveView socket connected.
// The :set_locale router plug only runs on the dead (HTTP) render; the
// connected LiveView mount restored nothing, so it fell back to the default
// locale. TypsterWeb.RestoreLocale now restores it on mount. The login page
// is a public LiveView (live_session :current_user) that carries the nav
// language toggle, so no auth is needed.
test.describe('Locale switching', () => {
  test('keeps the chosen language after the LiveView connects', async ({ page }) => {
    await page.goto('/users/log-in')
    await page.waitForFunction(() => window.liveSocket?.isConnected?.(), null, { timeout: 10_000 })

    // Default locale is English; the toggle offers switching to Russian.
    const toggle = page.getByRole('link', { name: 'Switch language' })
    await expect(toggle).toHaveText('RU')

    // Switch to Russian — a full navigation: GET /locale/ru -> redirect back.
    await toggle.click()
    await expect(toggle).toHaveText('EN')

    // The revert happened on connect, so re-confirm after the socket joins and
    // any connected re-render has settled. With the bug this flips back to 'RU'.
    await page.waitForFunction(() => window.liveSocket?.isConnected?.(), null, { timeout: 10_000 })
    await page.waitForTimeout(500)
    await expect(toggle).toHaveText('EN')

    // Reset to English so the run is idempotent.
    await toggle.click()
    await page.waitForFunction(() => window.liveSocket?.isConnected?.(), null, { timeout: 10_000 })
    await expect(toggle).toHaveText('RU')
  })
})
