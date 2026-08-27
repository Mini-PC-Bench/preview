const { test, expect } = require('playwright/test');

test('filters devices by name', async ({ page }) => {
  await page.goto('/');
  const device = page.locator('.device-name-trigger').first();
  const deviceName = await device.locator('span').first().textContent();

  await page.locator('#search').fill(deviceName);

  await expect(page.locator('#benchmark-table tbody .device-name-trigger')).toHaveCount(1);
  await expect(page.locator('#count')).toHaveText(/Showing 1 of \d+ devices/);
});

test('sorts the table when a benchmark header is selected', async ({ page }) => {
  await page.goto('/');
  const header = page.locator('th[data-col="cb23s"]').first();

  await header.click();
  await expect(header).toHaveClass(/active/);
  const firstIndicator = await header.locator('.sort-ind').textContent();

  await header.click();
  const secondIndicator = await header.locator('.sort-ind').textContent();
  expect(secondIndicator).not.toBe(firstIndicator);
});

test('persists selected columns across reloads', async ({ page }) => {
  await page.goto('/');
  await page.locator('#column-toggle').click();
  const option = page.locator('#column-options input[value="gbai_cpu"]');
  await option.check();
  await expect(page.locator('th[data-col="gbai_cpu"]').first()).toBeVisible();

  await page.reload();
  await expect(page.locator('th[data-col="gbai_cpu"]').first()).toBeVisible();
});
