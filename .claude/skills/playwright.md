---
name: playwright-patterns
description: >
  Playwright best practices and resilient automation patterns. Auto-loaded by the
  qa-executor agent. Contains selector strategies, wait patterns, auth handling,
  CI configuration, flakiness prevention, and screenshot/trace capture patterns.
  Use when writing or reviewing Playwright test code.
---

# Playwright Patterns — Resilient Browser Automation

This skill encodes hard-won Playwright best practices for the QA executor agent.
The goal: tests that pass when the app works and fail *only* when it doesn't.

> **Two modes exist — know which you're in:**
> - **CI/Automated (this skill)** — headless, script-based, structured JSON output, no human watching
> - **Interactive/Exploratory** — `lackeyjb/playwright-skill` plugin, headed browser, human-in-the-loop
>
> The executor agent always uses CI mode. For live interactive sessions, install the plugin separately.

---

## Selector Priority (most → least resilient)

Always pick the highest-priority selector available:

```javascript
// ✅ 1st choice — ARIA role + accessible name (most resilient)
page.getByRole('button', { name: 'Submit Order' })
page.getByRole('textbox', { name: 'Email address' })
page.getByRole('link', { name: 'Sign in' })
page.getByRole('checkbox', { name: 'Remember me' })

// ✅ 2nd choice — Label text
page.getByLabel('Password')
page.getByLabel('Search products')

// ✅ 3rd choice — Placeholder
page.getByPlaceholder('Enter your email')

// ✅ 4th choice — Test ID (if app has them)
page.getByTestId('submit-button')
page.locator('[data-testid="user-menu"]')

// ✅ 5th choice — Visible text
page.getByText('Welcome back')
page.locator('text=Add to cart')

// ⚠️ Last resort — CSS/XPath (fragile, changes with refactors)
page.locator('.btn-primary')         // BAD: class names change
page.locator('div:nth-child(2)')     // BAD: position changes
page.locator('#dynamicId_abc123')    // BAD: generated IDs change
```

**When using `getByRole`, always include `name`** to avoid matching multiple elements.

---

## Wait Strategies (never use fixed timeouts)

```javascript
// ✅ Wait for navigation to complete
await page.waitForURL('**/dashboard', { timeout: 10000 });
await page.waitForURL(url => !url.includes('/login'), { timeout: 8000 });

// ✅ Wait for element state
await page.waitForSelector('.success-toast', { state: 'visible', timeout: 5000 });
await page.waitForSelector('.loading-spinner', { state: 'hidden', timeout: 10000 });

// ✅ Wait for network to settle (use sparingly — slow on SPAs)
await page.waitForLoadState('networkidle', { timeout: 15000 });
await page.waitForLoadState('domcontentloaded');

// ✅ Wait for specific response
await page.waitForResponse(resp => resp.url().includes('/api/upload') && resp.status() === 200);

// ✅ Playwright auto-waits — these don't need explicit waits
await page.getByRole('button', { name: 'Submit' }).click(); // auto-waits for clickable
await page.getByLabel('Email').fill('test@test.com');        // auto-waits for editable

// ❌ NEVER do this
await page.waitForTimeout(3000); // fixed timeout = flaky test
await new Promise(r => setTimeout(r, 2000)); // same problem
```

---

## Assertion Patterns

```javascript
const { expect } = require('@playwright/test');

// ✅ Element visibility
await expect(page.getByText('Order confirmed')).toBeVisible({ timeout: 5000 });
await expect(page.getByRole('alert')).toBeVisible();

// ✅ URL assertion
await expect(page).toHaveURL('/dashboard');
await expect(page).toHaveURL(/.*\/order\/\d+/);

// ✅ Input value
await expect(page.getByLabel('Email')).toHaveValue('user@example.com');

// ✅ Count assertion
await expect(page.locator('.product-card')).toHaveCount(6);
await expect(page.locator('.error-message')).toHaveCount(0); // assert NO errors

// ✅ Text content
await expect(page.locator('h1')).toHaveText('Welcome, John');
await expect(page.locator('.price')).toContainText('$');

// ✅ Attribute assertion
await expect(page.getByRole('button', { name: 'Submit' })).toBeDisabled();
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();

// ✅ Network assertion — intercept API call and check it was made
const responsePromise = page.waitForResponse('**/api/checkout');
await page.getByRole('button', { name: 'Place Order' }).click();
const response = await responsePromise;
expect(response.status()).toBe(200);
```

---

## Authentication Patterns

### Pattern 1: storageState reuse (preferred for CI — fastest)
```javascript
// global-setup: run once, save state
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
await page.goto(`${BASE_URL}/login`);
await page.getByLabel('Email').fill(process.env.QA_USERNAME);
await page.getByLabel('Password').fill(process.env.QA_PASSWORD);
await page.getByRole('button', { name: /sign in|log in/i }).click();
await page.waitForURL(url => !url.includes('/login'));
await page.context().storageState({ path: '/tmp/qa-auth-state.json' });
await browser.close();

// In each test: restore state (no login needed)
const context = await browser.newContext({
  storageState: '/tmp/qa-auth-state.json'
});
```

### Pattern 2: API-level auth (fastest — skip UI login)
```javascript
// Use API to get token, inject as cookie/localStorage
const response = await request.post(`${BASE_URL}/api/auth/login`, {
  data: { email: process.env.QA_USERNAME, password: process.env.QA_PASSWORD }
});
const { token } = await response.json();

const context = await browser.newContext();
await context.addInitScript(token => {
  localStorage.setItem('auth_token', token);
}, token);
```

### Pattern 3: Adaptive login (for unknown apps)
```javascript
// Try common login page patterns in order
const loginUrl = `${BASE_URL}/login`;
await page.goto(loginUrl);

// Try selectors in order of likelihood
const emailInput = await page.locator([
  'input[type="email"]',
  'input[name="email"]',
  'input[name="username"]',
  'input[placeholder*="email" i]',
  'input[placeholder*="username" i]'
].join(',')).first();

await emailInput.fill(process.env.QA_USERNAME);

const passwordInput = page.locator('input[type="password"]').first();
await passwordInput.fill(process.env.QA_PASSWORD);

const submitBtn = await page.locator([
  'button[type="submit"]',
  'input[type="submit"]',
  'button:has-text("Sign in")',
  'button:has-text("Log in")',
  'button:has-text("Login")'
].join(',')).first();

await submitBtn.click();
```

---

## Handling Dynamic Content

```javascript
// SPA with skeleton loading
await page.waitForSelector('.skeleton-loader', { state: 'hidden', timeout: 10000 });
await page.waitForSelector('.content-loaded', { state: 'visible', timeout: 5000 });

// Infinite scroll / lazy loading
await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
await page.waitForLoadState('networkidle');

// Modal/dialog
await page.getByRole('dialog').waitFor({ state: 'visible', timeout: 5000 });
await page.getByRole('button', { name: 'Confirm' }).click();
await page.getByRole('dialog').waitFor({ state: 'hidden', timeout: 5000 });

// Toast notifications
await expect(page.getByRole('alert')).toBeVisible({ timeout: 5000 });
const toastText = await page.getByRole('alert').textContent();

// File download
const downloadPromise = page.waitForEvent('download');
await page.getByRole('button', { name: 'Download' }).click();
const download = await downloadPromise;
const fileName = download.suggestedFilename();
```

---

## Network Interception (for negative tests)

```javascript
// Simulate server error
await page.route('**/api/upload', route =>
  route.fulfill({ status: 500, body: 'Internal Server Error' })
);

// Simulate slow network
await page.route('**/*', route => {
  setTimeout(() => route.continue(), 2000); // 2s delay
});

// Mock specific API response
await page.route('**/api/users/me', route =>
  route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ id: 1, name: 'Test User', role: 'admin' })
  })
);

// Block specific resource (ads, analytics)
await page.route('**/*.{png,jpg,jpeg}', route => route.abort());
```

---

## CI-Specific Configuration

```javascript
// playwright.config.js for CI runs
const isCI = process.env.CI === 'true';

module.exports = {
  timeout: isCI ? 60000 : 30000,   // longer timeout in CI
  retries: isCI ? 2 : 0,           // retry flaky tests in CI only
  workers: isCI ? 1 : undefined,    // single worker in CI (more stable)
  reporter: isCI ? 'github' : 'list',

  use: {
    headless: isCI,                  // headless in CI, headed locally
    screenshot: 'only-on-failure',   // capture on failure always
    trace: 'retain-on-failure',      // trace for debugging failures
    video: isCI ? 'retain-on-failure' : 'off', // video in CI only
    actionTimeout: 10000,            // 10s per action
    navigationTimeout: 30000,        // 30s per navigation
    baseURL: process.env.APP_URL,
  }
};
```

---

## Screenshot Best Practices

```javascript
// ✅ Full page screenshot for state documentation
await page.screenshot({
  path: `/tmp/qa-screenshots/${testId}-before.png`,
  fullPage: true
});

// ✅ Element screenshot for focused evidence
await page.locator('.error-banner').screenshot({
  path: `/tmp/qa-screenshots/${testId}-error.png`
});

// ✅ Always screenshot BEFORE an assertion that might fail
await page.screenshot({ path: `/tmp/qa-screenshots/${testId}-pre-assert.png` });
await expect(page.getByText('Success')).toBeVisible();

// ✅ Screenshot on catch
try {
  await expect(page.getByText('Order confirmed')).toBeVisible({ timeout: 5000 });
} catch (err) {
  await page.screenshot({ path: `/tmp/qa-screenshots/${testId}-failure.png`, fullPage: true });
  throw err; // re-throw after capturing evidence
}
```

---

## Common Anti-Patterns to Avoid

```javascript
// ❌ Brittle CSS class selectors
await page.click('.btn-primary.submit-action.ml-2'); // breaks on any styling change

// ❌ nth-child / index-based selectors
await page.locator('li:nth-child(3)').click(); // breaks if list order changes

// ❌ Fixed waits
await page.waitForTimeout(3000);

// ❌ Asserting only on click, not on outcome
await page.click('button');
// MISSING: assertion that something actually happened

// ❌ Using page.evaluate for what Playwright can do natively
await page.evaluate(() => document.querySelector('button').click()); // use page.click() instead

// ❌ Swallowing errors silently
try {
  await page.click('.maybe-exists');
} catch {} // never silently ignore failures

// ❌ Sharing state between tests
let sharedPage; // don't share browser contexts between test cases
```

---

## Flakiness Diagnosis Checklist

When a test is flaky (passes sometimes, fails sometimes):

1. **Timing issue** — add `waitForLoadState` or `waitForSelector` before the failing step
2. **Stale element** — use `page.locator()` (lazy) instead of `page.$()` (eager)
3. **Race condition** — await the network response before asserting UI state
4. **CSS animation** — add `await page.waitForFunction(() => !document.querySelector('.animating'))`
5. **Dynamic IDs** — switch to role/label/text selectors
6. **CI vs local** — increase timeout for CI, check if CI has slower network
7. **Test pollution** — ensure each test starts with clean state (fresh context)
8. **Font loading** — add `await page.waitForLoadState('networkidle')` before screenshots