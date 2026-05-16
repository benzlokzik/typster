import { test as setup, expect } from '@playwright/test'
import path from 'path'
import { fileURLToPath } from 'url'
import fs from 'fs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
export const authFile = path.join(__dirname, '.auth/session.json')

setup('authenticate', async ({ page }) => {
  const email = `e2e-${Date.now()}-${Math.random().toString(36).slice(2)}@typster.test`

  await page.goto('/')
  const csrfToken = await page.evaluate(
    () => document.querySelector('meta[name="csrf-token"]')?.content ?? ''
  )

  // Submit the form via the browser so the resulting session cookie lands
  // directly in the browser context.
  //
  // Start watching for navigation BEFORE triggering submit so we don't miss
  // the redirect that immediately follows the POST response.
  const [_response] = await Promise.all([
    page.waitForNavigation({ waitUntil: 'load', timeout: 15_000 }),
    page.evaluate(({ email, csrfToken }) => {
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = '/dev/test-login'

      const addField = (name, value) => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = name
        input.value = value
        form.appendChild(input)
      }

      addField('email', email)
      addField('_csrf_token', csrfToken)
      document.body.appendChild(form)
      form.submit()
    }, { email, csrfToken }),
  ])

  // The controller should redirect to /projects, but if anything in the
  // session caused a different redirect, navigate there explicitly.
  // The session cookie is established regardless of where we landed.
  if (!page.url().includes('/projects')) {
    await page.goto('/projects', { waitUntil: 'load', timeout: 10_000 })
  }

  await page.waitForURL(/\/projects/, { timeout: 10_000 })
  await page.waitForFunction(() => window.liveSocket?.isConnected?.(), null, { timeout: 10_000 })

  fs.mkdirSync(path.dirname(authFile), { recursive: true })
  await page.context().storageState({ path: authFile })
})
