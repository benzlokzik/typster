import { defineConfig, devices } from "@playwright/test"

const port = process.env.PORT || "4000"
const baseURL = process.env.PLAYWRIGHT_BASE_URL || `http://127.0.0.1:${port}`

export default defineConfig({
  testDir: "./e2e",
  timeout: 20_000,
  expect: {
    timeout: 5_000
  },
  use: {
    baseURL,
    trace: "retain-on-failure"
  },
  webServer: {
    command: `cd .. && PHX_SERVER=true PORT=${port} mix phx.server`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ]
})
