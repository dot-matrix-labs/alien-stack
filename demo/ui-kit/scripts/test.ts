// test.ts - Playwright test: verify button renders on load
// Usage: bun run scripts/test.ts

import { chromium } from 'playwright';

const PORT = 0; // random available port
const PUBLIC_DIR = `${process.cwd()}/public`;

let exitCode = 0;

function pass(msg: string) { console.log(`  ✓ ${msg}`); }
function fail(msg: string) { console.error(`  ✗ ${msg}`); exitCode = 1; }

const server = Bun.serve({
  port: PORT,
  fetch(req) {
    const url = new URL(req.url);
    let filePath = url.pathname === '/' ? '/index.html' : url.pathname;
    const file = Bun.file(PUBLIC_DIR + filePath);
    if (file.exists()) return new Response(file);
    return new Response('Not Found', { status: 404 });
  },
});

const baseUrl = `http://localhost:${server.port}`;
console.log(`Serving public/ at ${baseUrl}`);

const browser = await chromium.launch({
  headless: true,
  args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
});

const page = await browser.newPage();

const consoleErrors: string[] = [];
page.on('pageerror', err => consoleErrors.push(err.message));

let alertMessage: string | null = null;
page.on('dialog', async dialog => {
  alertMessage = dialog.message();
  await dialog.dismiss();
});

try {
  console.log('\nLoading page...');
  await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 15000 });

  // Wait for the Wasm-rendered button to appear
  const button = await page.waitForSelector('button', { timeout: 5000 })
    .catch(() => null);

  if (!button) {
    fail('No <button> element found in DOM');
  } else {
    pass('<button> element present');

    const text = await button.textContent();
    if (text?.trim() === 'Submit') {
      pass('Button text is "Submit"');
    } else {
      fail(`Button text is "${text?.trim()}" — expected "Submit"`);
    }

    const visible = await button.isVisible();
    if (visible) {
      pass('Button is visible');
    } else {
      fail('Button is not visible');
    }

    // Click the button and verify it triggers a window.alert via Wasm on_event
    await button.click();
    await page.waitForTimeout(500);
    if (alertMessage === 'Button clicked') {
      pass('Button click triggers alert "Button clicked"');
    } else {
      fail(`Expected alert "Button clicked" — got: ${alertMessage ?? '(none)'}`);
    }
  }

  if (consoleErrors.length > 0) {
    fail(`Page errors: ${consoleErrors.join('; ')}`);
  } else {
    pass('No page errors');
  }

} catch (e) {
  fail(`Unexpected error: ${e}`);
} finally {
  await browser.close();
  server.stop();
}

console.log(`\n${exitCode === 0 ? '✓ All tests passed' : '✗ Tests failed'}`);
process.exit(exitCode);
