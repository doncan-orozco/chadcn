import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// InputOTP (input-otp re-implemented in the chadcn--input-otp controller). What the parity runner cannot express: the two events
// and their detail, the paste paths (iOS and pasteTransformer need a clipboard), the global stylesheet, the fake caret mounting
// and cleanup. Typing, selection, pattern and focus parity against input-otp itself is covered by the scenarios (G2/G3).
browserTest.component = "input-otp";
const input = "[data-slot=input-otp]";
const container = "[data-input-otp-container]";
const slots = (page) => page.locator("[data-slot=input-otp-slot]").evaluateAll((els) => els.map((el) => [el.textContent.trim(), el.dataset.active]));

// Records the public events of the controller in window.__events.
const record = (page) => page.evaluate(() => {
  window.__events = [];
  for (const name of ["change", "complete"]) {
    document.addEventListener(`chadcn--input-otp:${name}`, (event) => window.__events.push({ name, detail: event.detail, cancelable: event.cancelable, bubbles: event.bubbles }));
  }
});
const events = (page) => page.evaluate(() => window.__events);
const paste = (page, text) => page.locator(input).evaluate((el, data) => {
  const clipboardData = new DataTransfer();
  clipboardData.setData("text/plain", data);
  el.dispatchEvent(new ClipboardEvent("paste", { clipboardData, bubbles: true, cancelable: true }));
}, text);

browserTest("input-otp: change fires for every accepted input and complete once the value reaches max-length", async ({ open }) => {
  const page = await open("focus__tab");
  await record(page);
  await page.focus(input);
  await page.keyboard.type("123456");
  await settle(page);
  const log = await events(page);
  assert.deepEqual(log.filter((e) => e.name === "change").map((e) => e.detail.value), ["1", "12", "123", "1234", "12345", "123456"]);
  assert.deepEqual(log.filter((e) => e.name === "complete").map((e) => e.detail.value), ["123456"]);
  assert.ok(log.every((e) => e.bubbles && !e.cancelable));
  await page.keyboard.press("Backspace");
  await settle(page);
  assert.deepEqual((await events(page)).filter((e) => e.name === "complete").length, 1, "deleting does not complete again");
});

browserTest("input-otp: a value rejected by the pattern dispatches nothing and keeps the rendered value", async ({ open }) => {
  const page = await open("pattern-digits__type-rejects-letter");
  await record(page);
  await page.focus(input);
  await page.keyboard.type("1a2");
  await settle(page);
  assert.equal(await page.locator(input).inputValue(), "12");
  assert.deepEqual((await events(page)).filter((e) => e.name === "change").map((e) => e.detail.value), ["1", "12"]);
});

browserTest("input-otp: a controlled value reports the attempted value and the input goes back to the rendered one", async ({ open }) => {
  const page = await open("controlled__value-without-feedback");
  await record(page);
  await page.focus(input);
  await page.keyboard.type("3");
  await settle(page);
  assert.equal(await page.locator(input).inputValue(), "12");
  assert.deepEqual((await events(page)).filter((e) => e.name === "change").map((e) => e.detail.value), ["123"]);
  assert.deepEqual((await slots(page)).slice(0, 3).map(([char]) => char), ["1", "2", ""]);
});

browserTest("input-otp: the fake caret is mounted in the active empty slot only and removed when the input blurs", async ({ open }) => {
  const page = await open("default");
  assert.equal(await page.locator("[data-slot=input-otp-slot] .animate-caret-blink").count(), 0);
  await page.focus(input);
  await settle(page);
  assert.equal(await page.locator("[data-slot=input-otp-slot][data-active=true] .animate-caret-blink").count(), 1);
  await page.keyboard.type("1");
  await settle(page);
  assert.equal(await page.locator(".animate-caret-blink").count(), 1, "the caret moved to the next slot");
  assert.deepEqual((await slots(page)).map(([, active]) => active), ["false", "true", "false", "false"]);
  await page.locator(input).blur();
  await settle(page);
  assert.equal(await page.locator(".animate-caret-blink").count(), 0);
  assert.deepEqual((await slots(page)).map(([, active]) => active), ["false", "false", "false", "false"]);
});

browserTest("input-otp: the global stylesheet is injected once, with its five rules, and kept", async ({ open }) => {
  const page = await open("default");
  assert.equal(await page.locator("style#input-otp-style").count(), 1);
  assert.equal(await page.evaluate(() => document.getElementById("input-otp-style").sheet.cssRules.length), 5);
});

browserTest("input-otp: a pasteTransformer assigned from JavaScript transforms, splices and truncates a paste", async ({ open }) => {
  const page = await open("focus__tab");
  await record(page);
  await page.evaluate(() => {
    const controller = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-input-otp-container]"), "chadcn--input-otp");
    controller.pasteTransformer = (text) => text.replace(/\D/g, "");
  });
  await page.focus(input);
  await paste(page, "12-34");
  await settle(page);
  assert.equal(await page.locator(input).inputValue(), "1234");
  assert.deepEqual((await events(page)).filter((e) => e.name === "change").map((e) => e.detail.value), ["1234"]);
  await paste(page, "5678-90");
  await settle(page);
  assert.equal(await page.locator(input).inputValue(), "123456", "truncated to max-length");
  assert.deepEqual((await events(page)).filter((e) => e.name === "complete").map((e) => e.detail.value), ["123456"]);
});

browserTest("input-otp: the container height feeds the input font size and a disabled input has the default cursor", async ({ open }) => {
  const page = await open("disabled");
  assert.match(await page.locator(container).evaluate((el) => el.style.getPropertyValue("--root-height")), /^\d+(\.\d+)?px$/);
  assert.equal(await page.locator(container).evaluate((el) => el.style.cursor), "default");
});

browserTest("input-otp: removing the element stops the timers and listeners (no error after disconnect)", async ({ open }) => {
  const page = await open("focus__tab");
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.clock.install();
  await page.focus(input);
  await page.clock.runFor(1);
  const badgeChecked = () => page.evaluate(() => window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-input-otp-container]"), "chadcn--input-otp").badge.hasBadge);
  assert.equal(await badgeChecked(), true, "control: the 0 ms badge check ran on the fake clock while connected");
  await page.locator(container).evaluate((el) => el.remove());
  await page.clock.runFor(7000);
  await page.evaluate(() => document.dispatchEvent(new Event("selectionchange")));
  assert.deepEqual(errors, []);
});

browserTest("input-otp: a snapshot taken while focused reconnects blurred, without a stale caret", async ({ open }) => {
  const page = await open("default");
  await page.focus(input);
  await page.keyboard.type("1");
  await settle(page);
  assert.equal(await page.locator("[data-slot=input-otp-slot][data-active=true]").count(), 1, "control: one active slot");
  assert.equal(await page.locator(".animate-caret-blink").count(), 1, "control: the caret is mounted");
  await page.locator(container).evaluate((el) => el.replaceWith(el.cloneNode(true)));
  await settle(page);
  assert.deepEqual(await slots(page), [["1", "false"], ["", "false"], ["", "false"], ["", "false"]]);
  assert.equal(await page.locator(".animate-caret-blink").count(), 0);
});
