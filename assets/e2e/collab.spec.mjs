import { test, expect } from '@playwright/test'

// Live collaborative editing (Yjs over a Phoenix channel). Two editor pages in
// one authenticated context are two distinct Yjs clients on the same server
// document: an edit in one must appear in the other, and each must paint the
// other's remote caret. Requires the server booted with TYPSTER_COLLAB=1.
//
// Collab is off by default in the test env (it makes Y.Text the editor's source
// of truth, which the other editor specs don't expect), so this spec self-skips
// unless the server was booted with the flag. Run it with:
//   MIX_ENV=test TYPSTER_COLLAB=1 PORT=4099 bunx playwright test e2e/collab.spec.mjs --project=chromium-authenticated
test.skip(process.env.TYPSTER_COLLAB !== '1', 'collaboration disabled (set TYPSTER_COLLAB=1)')

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
  const draftInput = page.locator('#new-file-form input[name="path"]')
  await expect(draftInput).toBeVisible()
  await draftInput.fill('main.typ')
  await draftInput.press('Enter')
  await expect(page.locator('#editor-container .cm-content')).toBeVisible({ timeout: 10_000 })
}

test('live co-editing syncs both ways and renders remote cursors', async ({ context }) => {
  test.setTimeout(120_000)

  // Editor A creates the project + file.
  const a = await context.newPage()
  await createProjectAndOpenEditor(a, `collab-${Date.now()}`)
  await addMainFile(a)
  // The editor must be in collab mode for this test to mean anything.
  await expect(a.locator('#editor-container')).toHaveAttribute('data-collab', 'true')
  const editorUrl = a.url()

  // Editor B opens the same file (same session = authorized; distinct Yjs client).
  const b = await context.newPage()
  await b.goto(editorUrl)
  await expect(b.locator('#editor-container .cm-content')).toBeVisible({ timeout: 15_000 })

  const aContent = a.locator('#editor-container .cm-content')
  const bContent = b.locator('#editor-container .cm-content')

  // A → B.
  await aContent.click()
  await a.keyboard.type('HELLO_FROM_A')
  await expect(bContent).toContainText('HELLO_FROM_A', { timeout: 15_000 })

  // B → A (append, so we exercise a concurrent insert at a different offset).
  await bContent.click()
  await b.keyboard.press('Control+End')
  await b.keyboard.type(' PLUS_FROM_B')
  await expect(aContent).toContainText('PLUS_FROM_B', { timeout: 15_000 })

  // Remote presence: each editor paints the other client's caret.
  await expect(a.locator('.cm-ySelectionCaret').first()).toBeVisible({ timeout: 10_000 })
  await expect(b.locator('.cm-ySelectionCaret').first()).toBeVisible({ timeout: 10_000 })
})
