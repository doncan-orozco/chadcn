import { browserTest } from "./harness.mjs";
import { assert, eventLog, recordEvents, settle } from "./support.mjs";
import { positioningTests } from "./positioning.mjs";

browserTest.component = "popover";
const trigger = "[data-slot=popover-trigger]";
const content = "[data-slot=popover-content]";
const isOpen = (page) => page.locator(content).count().then((n) => n > 0);
const close = async (page) => { await page.keyboard.press("Escape"); await page.waitForSelector(content, { state: "detached" }); };
const open = async (page) => { await page.click(trigger); await page.waitForSelector(content); await settle(page); };

browserTest("popover: open-change fires with the requested state on every change", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "chadcn--popover");
  await open(page);
  await page.keyboard.press("Escape");
  await page.waitForSelector(content, { state: "detached" });
  const log = (await eventLog(page)).filter((e) => e.name === "open-change");
  assert.deepEqual(log.map((e) => e.open), [true, false]);
});

browserTest("popover: a caller preventDefault on escape-key-down keeps the popover open", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "chadcn--popover", { prevent: ["escape-key-down"] });
  await open(page);
  await page.keyboard.press("Escape");
  await settle(page);
  assert.ok(await isOpen(page));
  assert.deepEqual((await eventLog(page)).filter((e) => e.name === "escape-key-down").map((e) => e.cancelable), [true]);
});

browserTest("popover: escape-key-down without preventDefault closes", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "chadcn--popover");
  await open(page);
  await page.keyboard.press("Escape");
  await page.waitForSelector(content, { state: "detached" });
});

for (const prevented of ["interact-outside", "pointer-down-outside"]) {
  browserTest(`popover: a caller preventDefault on ${prevented} keeps the popover open after an outside click`, async ({ open: openPage }) => {
    const page = await openPage("default__closed");
    await recordEvents(page, "chadcn--popover", { prevent: [prevented] });
    await open(page);
    await page.click("[data-testid=outside]");
    await settle(page);
    assert.ok(await isOpen(page), `${prevented} prevented`);
    assert.ok((await eventLog(page)).some((e) => e.name === prevented));
  });
}

browserTest("popover: an outside click closes and fires pointer-down-outside then interact-outside", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "chadcn--popover");
  await open(page);
  await page.click("[data-testid=outside]");
  await page.waitForSelector(content, { state: "detached" });
  const names = (await eventLog(page)).map((e) => e.name);
  assert.ok(names.indexOf("pointer-down-outside") < names.indexOf("interact-outside"), names.join(","));
});

// Radix defers a primary press outside to the document `click` (bubbling), so a handler that stops the click intercepts the dismissal.
browserTest("popover: an outside element that stops the click intercepts the dismissal, like Radix", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await page.evaluate(() => document.querySelector("[data-testid=outside]").addEventListener("click", (e) => e.stopPropagation()));
  await open(page);
  await page.click("[data-testid=outside]");
  await settle(page);
  assert.ok(await isOpen(page));
});

browserTest("popover: open-auto-focus and close-auto-focus are cancelable", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "chadcn--popover", { prevent: ["close-auto-focus"] });
  await open(page);
  await page.keyboard.press("Escape");
  await page.waitForSelector(content, { state: "detached" });
  const log = await eventLog(page);
  assert.ok(log.filter((e) => e.name.endsWith("auto-focus")).every((e) => e.cancelable));
  assert.notEqual(await page.evaluate(() => document.activeElement?.dataset.slot), "popover-trigger", "prevented close-auto-focus must not return focus to the trigger");
});

positioningTests(browserTest, {
  component: "popover", scenario: "default__closed", template: "template[data-chadcn--popover-template]", controller: "chadcn--popover", trigger, content, open, close
});
