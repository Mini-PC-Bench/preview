const { test, expect } = require('playwright/test');

test('the benchmark dashboard loads without local errors', async ({ page, baseURL }) => {
  const localConsoleErrors = [];
  const localRequestFailures = [];

  page.on('console', message => {
    if (message.type() === 'error') localConsoleErrors.push(message.text());
  });
  page.on('requestfailed', request => {
    if (request.url().startsWith(baseURL)) localRequestFailures.push(request.url());
  });

  await page.goto('/');

  await expect(page).toHaveTitle('Mini PC Benchmark Comparison');
  await expect(page.locator('#site-meta')).toContainText(/\d+ devices/);
  await expect(page.locator('#benchmark-table tbody .device-name-trigger').first()).toBeVisible();
  await expect(page.locator('#changelog-link')).toHaveAttribute('href', './changelog.html');
  expect(localConsoleErrors).toEqual([]);
  expect(localRequestFailures).toEqual([]);
});
