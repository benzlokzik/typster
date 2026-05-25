import { test, expect } from '@playwright/test'

async function createProjectAndOpenEditor(page, name) {
  await page.goto('/projects')
  await page.waitForFunction(() => window.liveSocket?.isConnected?.(), null, { timeout: 10_000 })
  await page.locator('#new-project-button').click()
  await expect(page.locator('.ts-dialog')).toBeVisible()
  await page.locator('.ts-dialog input[name="name"]').fill(name)
  await page.locator('.ts-dialog button[type="submit"]').click()
  await expect(page.locator('.ts-dialog')).not.toBeVisible()

  const row = page.locator('.ts-list__row').filter({ hasText: name })
  await expect(row).toBeVisible()
  await row.getByRole('link', { name: 'Open' }).click()
  await expect(page).toHaveURL(/\/projects\/.+\/edit/)
}

async function addMainFile(page) {
  await page.locator('#create-main-file-button').click()
  await expect(page.locator('.ts-dialog')).toBeVisible()
  await page.locator('.ts-dialog input[name="path"]').fill('main.typ')
  await page.locator('.ts-dialog button[type="submit"]').click()
  await expect(page.locator('.ts-dialog')).not.toBeVisible()
  await expect(page.locator('#editor-container .cm-content')).toBeVisible({ timeout: 10_000 })
}

test.describe('Product UI redesign', () => {
  test('accent picker persists on the user record', async ({ page }) => {
    await page.goto('/users/settings')
    await page.waitForFunction(() => window.liveSocket?.isConnected?.(), null, { timeout: 10_000 })

    await page.locator('#accent-violet').click()
    await expect(page.locator('#accent-violet')).toHaveClass(/is-active/)
    await expect(page.locator('.ts-app')).toHaveAttribute('data-accent', 'violet')

    // survives a full reload (DB-backed, server-rendered)
    await page.reload()
    await expect(page.locator('.ts-app')).toHaveAttribute('data-accent', 'violet')
    await expect(page.locator('#accent-indigo')).toBeVisible()

    // reset so the run is idempotent
    await page.locator('#accent-indigo').click()
    await expect(page.locator('.ts-app')).toHaveAttribute('data-accent', 'indigo')
  })

  test('command palette opens and filters', async ({ page }) => {
    await createProjectAndOpenEditor(page, 'Palette E2E')
    await addMainFile(page)

    await page.getByRole('button', { name: '⌘K' }).click()
    await expect(page.locator('#command-palette')).toBeVisible()
    await expect(page.locator('#palette-input')).toBeFocused()

    await page.locator('#palette-input').fill('settings')
    await expect(page.locator('.ts-palette__item').filter({ hasText: 'Settings' })).toBeVisible()

    await page.keyboard.press('Escape')
    await expect(page.locator('#command-palette')).not.toBeVisible()
  })

  test('applies Shiki Typst syntax highlighting', async ({ page }) => {
    await createProjectAndOpenEditor(page, 'Highlight E2E')
    await addMainFile(page)

    // Shiki initializes asynchronously, then paints colored token spans.
    const colored = page.locator('#editor-container .cm-line span[style*="color"]')
    await expect(colored.first()).toBeVisible({ timeout: 15_000 })
    expect(await colored.count()).toBeGreaterThan(0)
  })

  test('formatting toolbar inserts markup into the editor', async ({ page }) => {
    await createProjectAndOpenEditor(page, 'Toolbar E2E')
    await addMainFile(page)

    const cm = page.locator('#editor-container .cm-content')
    await cm.click()
    await page.getByRole('button', { name: 'Bold' }).click()

    await expect(cm).toContainText('*')
  })

  test('download button exports the compiled document as a PDF', async ({ page }) => {
    await createProjectAndOpenEditor(page, 'Download E2E')
    await addMainFile(page)

    // Wait for the first preview render so the Typst worker WASM is initialized.
    await expect(page.locator('#typst-svg-output')).toBeVisible({ timeout: 20_000 })

    const downloadPromise = page.waitForEvent('download', { timeout: 30_000 })
    await page.getByRole('button', { name: 'Download' }).click()

    const download = await downloadPromise
    expect(download.suggestedFilename()).toBe('main.pdf')
  })
})
