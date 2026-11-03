import {defineConfig} from '@playwright/test';
export default defineConfig({
  testDir: './test/browser', timeout: 180000, workers: 1,
  expect: {timeout: 30000},
  use: {baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:8766',
    channel: 'chrome', viewport: {width: 1280, height: 900}, actionTimeout:30000,
    screenshot: 'only-on-failure', trace: 'retain-on-failure'},
  reporter: [['list'], ['json', {outputFile:'test-results/browser-report.json'}]],
});
