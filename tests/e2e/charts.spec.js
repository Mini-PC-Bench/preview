const { test, expect } = require('playwright/test');

test('switches from the table view to a benchmark chart', async ({ page }) => {
  await page.goto('/');
  await page.locator('.tab-btn[data-view="charts"]').click();

  await expect(page.locator('#charts-view')).toHaveClass(/active/);
  await expect(page.locator('#chart-box .chart-title')).toBeVisible();

  await page.locator('.chart-tab[data-chart="cb23m"]').click();
  await expect(page.locator('.chart-tab[data-chart="cb23m"]')).toHaveClass(/active/);
  await expect(page.locator('#chart-box')).not.toContainText('No chart data available.');
});
