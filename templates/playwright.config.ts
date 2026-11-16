import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["html", { open: "never" }]] : "list",
  use: { baseURL: "http://127.0.0.1:5173", trace: "on-first-retry" },
  webServer: {
    // --host 127.0.0.1 est indispensable : sur les runners GitHub, `localhost`
    // se résout en IPv6 seul et les sondes de Playwright échouent à l'infini.
    command: "npm run dev -- --port 5173 --strictPort --host 127.0.0.1",
    url: "http://127.0.0.1:5173",
    reuseExistingServer: !process.env.CI,
    // 60 s était trop juste sur les runners partagés (Vite + workerd à froid).
    timeout: 120_000,
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
