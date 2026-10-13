// A popover / hover card rendered inside an open modal Dialog: their content is portaled to <body>, outside the dialog's
// DOM, so the layer stack (dismissable layers) and the focus scopes must treat them as children of the dialog.
// No scenario can express this (a scenario tree may only use its own component), so the real popover markup is fetched
// from its parity page and mounted inside the dialog content of the dialog parity page.
import { browserTest } from "./harness.mjs";
import { assert, PHLEX, settle } from "./support.mjs";

browserTest.component = "dialog";
const dialog = "[data-slot=dialog-content]";

async function mountInDialog(page, component, selectors) {
  const html = await (await page.request.get(`${PHLEX}/design-system/parity/${component}/default__closed`)).text();
  await page.evaluate(({ html, selectors }) => {
    const doc = new DOMParser().parseFromString(html, "text/html");
    const host = document.querySelector("[data-slot=dialog-content]");
    for (const selector of selectors) host.append(document.importNode(doc.querySelector(selector), true));
  }, { html, selectors });
  await settle(page);
}

browserTest("popover inside a dialog: Escape closes only the popover, a second Escape closes the dialog", async ({ open }) => {
  const page = await open("open__default-open");
  await mountInDialog(page, "popover", ["[data-slot=popover-trigger]", "template[data-v2--popover-template]"]);
  await page.click("[data-slot=popover-trigger]");
  await page.waitForSelector("[data-slot=popover-content]");
  await settle(page);
  await page.keyboard.press("Escape");
  await page.waitForSelector("[data-slot=popover-content]", { state: "detached" });
  assert.equal(await page.locator(dialog).count(), 1, "the dialog is still open after the first Escape");
  await page.keyboard.press("Escape");
  await page.waitForSelector(dialog, { state: "detached" });
});

browserTest("popover inside a dialog: interacting with the popover content does not dismiss the dialog", async ({ open }) => {
  const page = await open("open__default-open");
  await mountInDialog(page, "popover", ["[data-slot=popover-trigger]", "template[data-v2--popover-template]"]);
  await page.click("[data-slot=popover-trigger]");
  await page.waitForSelector("[data-slot=popover-content]");
  await settle(page);
  await page.click("[data-slot=popover-content]");
  await settle(page);
  assert.equal(await page.locator(dialog).count(), 1, "the dialog stays open");
  assert.equal(await page.locator("[data-slot=popover-content]").count(), 1, "the popover stays open");
});

browserTest("popover inside a dialog: a click on the dialog (outside the popover) closes the popover and keeps the dialog", async ({ open }) => {
  const page = await open("open__default-open");
  await mountInDialog(page, "popover", ["[data-slot=popover-trigger]", "template[data-v2--popover-template]"]);
  await page.click("[data-slot=popover-trigger]");
  await page.waitForSelector("[data-slot=popover-content]");
  await settle(page);
  await page.click("[data-slot=dialog-title]");
  await page.waitForSelector("[data-slot=popover-content]", { state: "detached" });
  assert.equal(await page.locator(dialog).count(), 1);
});

browserTest("hover card inside a dialog: Escape closes only the card", async ({ open }) => {
  const page = await open("open__default-open");
  await mountInDialog(page, "hover-card", ["[data-slot=hover-card-trigger]", "template[data-v2--hover-card-template]"]);
  await page.hover("[data-slot=hover-card-trigger]");
  await page.waitForSelector("[data-slot=hover-card-content]", { timeout: 5000 });
  await settle(page);
  await page.keyboard.press("Escape");
  await page.waitForSelector("[data-slot=hover-card-content]", { state: "detached" });
  assert.equal(await page.locator(dialog).count(), 1, "the dialog is still open");
});

browserTest("tooltip inside a dialog: Escape closes only the tooltip, and clicking its content keeps the dialog", async ({ open }) => {
  const page = await open("open__default-open");
  await mountInDialog(page, "tooltip", ["[data-slot=tooltip-trigger]", "template[data-v2--tooltip-template]"]);
  await page.focus("[data-slot=tooltip-trigger]");
  await page.waitForSelector("[data-slot=tooltip-content]");
  await settle(page);
  await page.click("[data-slot=tooltip-content]");
  await settle(page);
  assert.equal(await page.locator(dialog).count(), 1, "the dialog survives a click on the tooltip content");
  await page.evaluate(() => document.activeElement?.blur());
  await page.focus("[data-slot=tooltip-trigger]");
  await page.waitForSelector("[data-slot=tooltip-content]");
  await page.keyboard.press("Escape");
  await page.waitForSelector("[data-slot=tooltip-content]", { state: "detached" });
  assert.equal(await page.locator(dialog).count(), 1, "the dialog is still open after the first Escape");
});
