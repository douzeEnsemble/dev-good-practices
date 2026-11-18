import { defineConfig, devices } from '@playwright/test';

// Les tests tournent sur le site construit (`npm run build`, dossier `_site/`), servi par le
// serveur statique de Python : aucune dépendance de plus.
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['html', { open: 'never' }]] : 'list',
  use: { baseURL: 'http://127.0.0.1:4173', trace: 'on-first-retry' },
  webServer: {
    // 127.0.0.1 explicite : `localhost` se résout en IPv6 seul sur les runners GitHub (CI-12).
    command: 'python3 -m http.server 4173 --bind 127.0.0.1 --directory _site',
    url: 'http://127.0.0.1:4173',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  projects: [
    { name: 'clair', use: { ...devices['Desktop Chrome'], colorScheme: 'light' } },
    { name: 'sombre', use: { ...devices['Desktop Chrome'], colorScheme: 'dark' } },
  ],
});
