import test, { after } from "node:test";
import { assert, consoleErrors, launch, openPath, settle } from "./support.mjs";

// One real Turbo.visit away from a page and back, so Turbo's own page cache (not a hand-dispatched turbo:before-cache plus
// outerHTML, as in turbo_disclosure and turbo_overlays) exercises the restore. Page one of dev/dummy's turbo-round-trip pair
// has a default-open collapsible and a dialog; Turbo Drive is on there, unlike on the parity pages.
const ONE = "/design-system/turbo-round-trip/one";
const collapsible = '[data-controller~="chadcn--collapsible"]';
const content = "[data-slot=collapsible-content]";
const trigger = "[data-slot=collapsible-trigger]";
const dialogTrigger = "[data-slot=dialog-trigger]";
const dialogContent = "[data-slot=dialog-content]";

const browserPromise = launch();
after(async () => { await (await browserPromise).close(); });

test("turbo: a real Turbo.visit away and back restores page one from Turbo's cache, closed dialog and open collapsible included", async () => {
  const page = await openPath(await browserPromise, ONE);
  try {
    const errors = consoleErrors(page);
    const requests = [];
    page.on("request", (request) => { const { pathname } = new URL(request.url()); if (pathname.startsWith("/design-system/turbo-round-trip/")) requests.push(pathname); });

    await page.locator(dialogTrigger).click();
    await page.waitForSelector(dialogContent);
    assert.equal(await page.evaluate(() => document.body.hasAttribute("data-scroll-locked")), true, "precondition: the open dialog locks scroll");

    // Turbo.visit renders page two from the network; before leaving, Turbo fires turbo:before-cache and snapshots page one.
    await page.evaluate(() => window.Turbo.visit("/design-system/turbo-round-trip/two"));
    await page.waitForSelector("#turbo-round-trip-two");
    assert.equal(await page.locator("#turbo-round-trip-one").count(), 0, "page one is gone");

    await page.goBack();
    await page.waitForSelector("#turbo-round-trip-one");
    await settle(page);

    // A restoration visit is served from the snapshot: page one is not requested again, it was only loaded by the first goto.
    assert.deepEqual(requests, ["/design-system/turbo-round-trip/two"], "page one is not fetched again on the way back");
    assert.equal(await page.locator(dialogContent).count(), 0, "the dialog was closed in the snapshot");
    assert.equal(await page.evaluate(() => document.body.hasAttribute("data-scroll-locked")), false, "no stale scroll lock");
    assert.equal(await page.locator(content).getAttribute("data-state"), "open");
    assert.ok(await page.locator(content).evaluate((el) => el.textContent.includes("Collapsible body")), "the open content is mounted");

    // The restored controllers are live ones, not frozen markup.
    await page.locator(trigger).click();
    await settle(page);
    assert.equal(await page.locator(collapsible).getAttribute("data-state"), "closed");
    await page.locator(dialogTrigger).click();
    await page.waitForSelector(dialogContent);
    assert.equal(await page.locator(dialogContent).count(), 1);

    assert.deepEqual(errors, []);
    assert.deepEqual(page.jsErrors, []);
  } finally {
    await page.context().close();
  }
});
