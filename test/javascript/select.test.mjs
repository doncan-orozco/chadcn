import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// Select (Radix Select re-implemented in the chadcn--select controller), against the real Phlex parity pages. The scenarios compare
// the DOM with React step by step; this file pins the behavior contract of dev/port/specs/select.md end to end: trigger keyboard and
// pointer (mouse opens on pointerdown, touch on click), focus on open, navigation and typeahead, selection, the public events and
// their cancelable defaults, controlled state, the body effects while open, the native bubble select a form submits, disconnect
// cleanup and the Turbo cache snapshot.
browserTest.component = "select";
const HOST = "[data-controller~='chadcn--select']";
const trigger = "[data-slot=select-trigger]";
const content = "[data-slot=select-content]";
const value = "[data-slot=select-value]";
const native = "form select[aria-hidden=true]";
const option = (page, name) => page.getByRole("option", { name, exact: true });

const press = async (page, key) => { await page.keyboard.press(key); await settle(page); };
const triggerState = (page) => page.locator(trigger).getAttribute("data-state");
const valueText = (page) => page.locator(value).textContent();
const focused = (page) => page.evaluate(() => {
  const el = document.activeElement;
  if (el?.getAttribute("role") === "option") return el.textContent.trim();
  return el?.dataset?.slot ?? el?.tagName;
});
const waitFocused = (page, name) => page.waitForFunction((name) => document.activeElement?.getAttribute("role") === "option" && document.activeElement.textContent.trim() === name, name);
const waitTriggerFocused = (page) => page.waitForFunction((selector) => document.activeElement === document.querySelector(selector), trigger);
const waitOpen = (page) => page.waitForSelector(`${content}[data-state=open]`);
const waitClosed = (page) => page.waitForFunction((selector) => !document.querySelector(selector), content);

// Keyboard open: focus the trigger, press the key, wait until the content is open and focus has landed inside it.
async function openWith(page, key = "Enter") {
  await page.focus(trigger);
  await page.keyboard.press(key);
  await waitOpen(page);
  await page.waitForFunction((selector) => document.querySelector(selector)?.contains(document.activeElement), content);
}

// Records the public events (name, detail, cancelable); `prevent` names are cancelled. Details carrying an originalEvent are
// recorded as {} (the DOM event does not serialize).
const record = (page, { prevent = [] } = {}) => page.evaluate((prevent) => {
  window.__events = [];
  for (const name of ["open-change", "value-change", "escape-key-down", "pointer-down-outside", "close-auto-focus"]) {
    document.addEventListener(`chadcn--select:${name}`, (event) => {
      window.__events.push({ name, detail: event.detail?.originalEvent ? {} : event.detail, cancelable: event.cancelable });
      if (prevent.includes(name)) event.preventDefault();
    });
  }
}, prevent);
const events = (page, name) => page.evaluate((name) => window.__events.filter((e) => !name || e.name === name), name);

// What the body carries while a modal layer is mounted.
const BODY_EFFECTS = () => ({
  scrollLocked: document.body.hasAttribute("data-scroll-locked"),
  pointerEvents: document.body.style.pointerEvents,
  guards: document.querySelectorAll("[data-radix-focus-guard]").length,
  hidden: [...document.body.children].filter((el) => el.getAttribute("data-aria-hidden") === "true").length
});
const bodyEffects = (page) => page.evaluate(BODY_EFFECTS);
const RELEASED = { scrollLocked: false, pointerEvents: "", guards: 0, hidden: 0 };

browserTest("select: a mouse press opens on pointerdown, a release without moving keeps it open and selects nothing", async ({ open }) => {
  const page = await open("open__click");
  await record(page);
  const box = await page.locator(trigger).boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  assert.equal(await triggerState(page), "closed", "precondition: closed");
  await page.mouse.down();
  await waitOpen(page);
  assert.equal(await triggerState(page), "open", "open before the release");
  await page.mouse.up();
  await settle(page);
  assert.equal(await triggerState(page), "open");
  assert.equal(await page.locator(content).count(), 1);
  assert.deepEqual(await events(page, "value-change"), []);
  assert.equal(await page.locator(trigger).getAttribute("data-placeholder"), "");
});

browserTest("select: press on the trigger, drag onto an item and release selects it", async ({ open }) => {
  const page = await open("select__press-drag-release");
  await record(page);
  await page.locator(trigger).hover();
  await page.mouse.down();
  await waitOpen(page);
  const target = await option(page, "Grapes").boundingBox();
  await page.mouse.move(target.x + target.width / 2, target.y + target.height / 2, { steps: 4 });
  await page.mouse.up();
  await waitClosed(page);
  assert.equal(await valueText(page), "Grapes");
  assert.deepEqual((await events(page, "value-change")).map((e) => e.detail), [{ value: "grapes" }]);
});

browserTest("select: touch opens on click, not on pointerdown, and a touched item selects on click", async ({ open }) => {
  const page = await open("open__click");
  await page.locator(trigger).dispatchEvent("pointerdown", { pointerType: "touch", button: 0, isPrimary: true, bubbles: true, cancelable: true });
  await settle(page);
  assert.equal(await triggerState(page), "closed", "a touch pointerdown alone does not open");
  await page.locator(trigger).tap();
  await waitOpen(page);
  assert.equal(await triggerState(page), "open");
  await option(page, "Banana").tap();
  await waitClosed(page);
  assert.equal(await valueText(page), "Banana");
}, { touch: true });

browserTest("select: Enter, Space, ArrowDown and ArrowUp open from the focused trigger; Escape while closed does nothing", async ({ open }) => {
  for (const key of ["Enter", " ", "ArrowDown", "ArrowUp"]) {
    const page = await open("open__click");
    await page.focus(trigger);
    await press(page, "Escape");
    assert.equal(await triggerState(page), "closed", `precondition for ${JSON.stringify(key)}: Escape on the closed trigger is a no-op`);
    await page.keyboard.press(key);
    await waitOpen(page);
    const t = page.locator(trigger);
    assert.equal(await t.getAttribute("aria-expanded"), "true", key);
    assert.equal(await t.getAttribute("aria-controls"), await page.locator(content).getAttribute("id"), key);
    assert.equal(await page.locator(content).getAttribute("role"), "listbox");
    await waitFocused(page, "Apple");
  }
});

browserTest("select: a disabled trigger does not open", async ({ open }) => {
  const page = await open("disabled__trigger");
  await page.locator(trigger).dispatchEvent("pointerdown", { pointerType: "mouse", button: 0, bubbles: true, cancelable: true });
  await page.locator(trigger).dispatchEvent("keydown", { key: "Enter", bubbles: true, cancelable: true });
  await settle(page);
  assert.equal(await page.locator(trigger).isDisabled(), true);
  assert.equal(await triggerState(page), "closed");
  assert.equal(await page.locator(content).count(), 0);
});

browserTest("select: opening focuses the selected item (aria-selected, data-highlighted, checked); without a value the first enabled item", async ({ open }) => {
  const page = await open("value__default-value");
  await openWith(page);
  await waitFocused(page, "Banana");
  const banana = option(page, "Banana");
  assert.equal(await banana.getAttribute("aria-selected"), "true");
  assert.equal(await banana.getAttribute("data-state"), "checked");
  assert.equal(await banana.getAttribute("data-highlighted"), "");
  assert.equal(await option(page, "Apple").getAttribute("data-state"), "unchecked");
  assert.equal(await option(page, "Apple").getAttribute("aria-selected"), "false");

  const disabledFirst = await open("open__first-disabled-focuses-next");
  await openWith(disabledFirst);
  await waitFocused(disabledFirst, "Banana");
  assert.equal(await option(disabledFirst, "Banana").getAttribute("aria-selected"), "false", "focused but not selected");
});

browserTest("select: arrows move between enabled items without looping, skip disabled ones; Home and End jump", async ({ open }) => {
  const page = await open("disabled-item__skipped-by-arrows");
  await openWith(page);
  await waitFocused(page, "Apple");
  await press(page, "ArrowUp");
  assert.equal(await focused(page), "Apple", "no loop at the start");
  await page.keyboard.press("ArrowDown");
  await waitFocused(page, "Blueberry");
  assert.equal(await option(page, "Banana").getAttribute("data-highlighted"), null);
  await page.keyboard.press("End");
  await waitFocused(page, "Pineapple");
  await press(page, "ArrowDown");
  assert.equal(await focused(page), "Pineapple", "no loop at the end");
  await page.keyboard.press("Home");
  await waitFocused(page, "Apple");
});

browserTest("select: typeahead while open focuses the next match and cycles on a repeated character", async ({ open }) => {
  const page = await open("open__click");
  await openWith(page);
  await waitFocused(page, "Apple");
  await page.keyboard.press("b");
  await waitFocused(page, "Banana");
  await page.keyboard.press("b");
  await waitFocused(page, "Blueberry");
  assert.equal(await triggerState(page), "open", "typeahead does not select");
  assert.equal(await page.locator(trigger).getAttribute("data-placeholder"), "");
});

browserTest("select: typeahead on the closed trigger changes the value without opening; Space during the search does not open", async ({ open }) => {
  const page = await open("open__click");
  await record(page);
  await page.focus(trigger);
  await press(page, "g");
  assert.equal(await triggerState(page), "closed");
  assert.equal(await valueText(page), "Grapes");
  assert.equal(await page.locator(trigger).getAttribute("data-placeholder"), null);
  assert.deepEqual((await events(page, "value-change")).map((e) => e.detail), [{ value: "grapes" }]);
  // The trigger's keydown ignores Space while searching (the native button click on keyup still opens, in Radix too), so the
  // keydown alone is dispatched: not prevented and nothing opens. The control is a Space keydown with an empty buffer.
  await press(page, "b");
  const spaceKeyDown = () => page.locator(trigger).evaluate((el) => !el.dispatchEvent(new KeyboardEvent("keydown", { key: " ", bubbles: true, cancelable: true })));
  assert.equal(await spaceKeyDown(), false, "Space during the search is not handled");
  await settle(page);
  assert.equal(await triggerState(page), "closed", "Space is part of the search");
  assert.deepEqual(await events(page, "open-change"), []);

  const control = await open("open__click");
  await control.focus(trigger);
  assert.equal(await control.locator(trigger).evaluate((el) => !el.dispatchEvent(new KeyboardEvent("keydown", { key: " ", bubbles: true, cancelable: true }))), true, "control: an idle Space keydown opens");
  await waitOpen(control);
});

browserTest("select: clicking an item selects it, updates the value text, closes and focuses the trigger", async ({ open }) => {
  const page = await open("open__click");
  await record(page);
  await page.click(trigger);
  await waitOpen(page);
  assert.equal(await valueText(page), "Select a fruit", "precondition: placeholder");
  await option(page, "Grapes").click();
  await waitClosed(page);
  await waitTriggerFocused(page);
  assert.equal(await valueText(page), "Grapes");
  assert.equal(await page.locator(trigger).getAttribute("data-placeholder"), null);
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false");
  assert.equal(await page.locator(trigger).getAttribute("aria-controls"), null);
  assert.deepEqual((await events(page)).map((e) => [e.name, e.detail]), [
    ["open-change", { open: true }], ["value-change", { value: "grapes" }], ["open-change", { open: false }], ["close-auto-focus", {}]
  ]);

  await openWith(page);
  await waitFocused(page, "Grapes");
  assert.equal(await option(page, "Grapes").getAttribute("data-state"), "checked", "reopening shows the new selection");
  assert.equal(await option(page, "Grapes").locator("[data-slot=select-item-indicator] svg").count(), 1);
});

browserTest("select: Enter and Space on the focused item select it; the same value again dispatches no value-change", async ({ open }) => {
  for (const key of ["Enter", " "]) {
    const page = await open("open__click");
    await record(page);
    await openWith(page);
    await page.keyboard.press("ArrowDown");
    await waitFocused(page, "Banana");
    await page.keyboard.press(key);
    await waitClosed(page);
    assert.equal(await valueText(page), "Banana", key);
    await openWith(page);
    await waitFocused(page, "Banana");
    await page.keyboard.press(key);
    await waitClosed(page);
    assert.deepEqual((await events(page, "value-change")).map((e) => e.detail), [{ value: "banana" }], `${JSON.stringify(key)}: once`);
  }
});

browserTest("select: Escape dispatches cancelable escape-key-down; preventing it keeps the select open", async ({ open }) => {
  const page = await open("open__click");
  await record(page, { prevent: ["escape-key-down"] });
  await openWith(page);
  await press(page, "Escape");
  assert.equal(await triggerState(page), "open");
  assert.deepEqual((await events(page, "escape-key-down")).map((e) => e.cancelable), [true]);

  const plain = await open("open__click");
  await record(plain);
  await openWith(plain);
  await plain.keyboard.press("Escape");
  await waitClosed(plain);
  await waitTriggerFocused(plain);
  assert.deepEqual((await events(plain, "open-change")).map((e) => e.detail), [{ open: true }, { open: false }]);
});

browserTest("select: outside pointerdown dispatches cancelable pointer-down-outside and closes unless prevented", async ({ open }) => {
  const page = await open("open__click");
  await record(page, { prevent: ["pointer-down-outside"] });
  await openWith(page);
  await page.mouse.click(5, 700);
  await settle(page);
  assert.equal(await triggerState(page), "open");
  assert.deepEqual((await events(page, "pointer-down-outside")).map((e) => e.cancelable), [true]);

  const plain = await open("open__click");
  await openWith(plain);
  await plain.mouse.click(5, 700);
  await waitClosed(plain);
  assert.equal(await triggerState(plain), "closed");
});

browserTest("select: close-auto-focus is cancelable and a prevented one leaves focus off the trigger", async ({ open }) => {
  const page = await open("open__click");
  await record(page, { prevent: ["close-auto-focus"] });
  await openWith(page);
  await page.keyboard.press("Escape");
  await waitClosed(page);
  await page.waitForFunction(() => window.__events.some((e) => e.name === "close-auto-focus"));
  await settle(page);
  assert.deepEqual((await events(page, "close-auto-focus")).map((e) => e.cancelable), [true]);
  assert.notEqual(await focused(page), "select-trigger");
});

browserTest("select: Tab is trapped in the open content; window blur and resize close it", async ({ open }) => {
  const page = await open("open__click");
  await openWith(page);
  await waitFocused(page, "Apple");
  await press(page, "Tab");
  await press(page, "Shift+Tab");
  assert.equal(await focused(page), "Apple");
  assert.equal(await triggerState(page), "open");
  await page.evaluate(() => window.dispatchEvent(new Event("blur")));
  await waitClosed(page);

  await openWith(page);
  await page.setViewportSize({ width: 1000, height: 700 });
  await waitClosed(page);
  assert.equal(await triggerState(page), "closed");
});

browserTest("select: controlled open and value dispatch their events but keep the server state", async ({ open }) => {
  const page = await open("open__controlled-closed-click-stays");
  await record(page);
  await page.click(trigger);
  await page.waitForFunction(() => window.__events.length > 0);
  await settle(page);
  assert.deepEqual((await events(page)).map((e) => e.detail), [{ open: true }]);
  assert.equal(await triggerState(page), "closed");
  assert.equal(await page.locator(content).count(), 0);

  const valued = await open("select__controlled-value-unchanged");
  await record(valued);
  await valued.click(trigger);
  await waitOpen(valued);
  await option(valued, "Grapes").click();
  await waitClosed(valued);
  assert.deepEqual((await events(valued, "value-change")).map((e) => e.detail), [{ value: "grapes" }]);
  assert.equal(await valueText(valued), "Apple", "the server value stays");
});

browserTest("select: while open the body is locked, guarded and its other children aria-hidden; closing releases all of it", async ({ open }) => {
  const page = await open("open__click");
  assert.deepEqual(await bodyEffects(page), RELEASED, "precondition: nothing applied");
  await openWith(page);
  const effects = await bodyEffects(page);
  assert.equal(effects.scrollLocked, true);
  assert.equal(effects.pointerEvents, "none");
  assert.equal(effects.guards, 2);
  assert.ok(effects.hidden > 0, "body siblings of the content are aria-hidden");
  assert.equal(await page.evaluate((selector) => document.querySelector(selector).closest("[aria-hidden=true]"), content), null, "the content stays exposed");
  await page.keyboard.press("Escape");
  await waitClosed(page);
  assert.deepEqual(await bodyEffects(page), RELEASED);
});

browserTest("select: in a form the native select follows the value and its change bubbles to the form", async ({ open }) => {
  const page = await open("form__native-select");
  assert.equal(await page.locator(native).getAttribute("name"), "fruit");
  assert.equal(await page.locator(native).inputValue(), "", "precondition: the placeholder option");
  await page.evaluate(() => {
    window.__changes = [];
    document.querySelector("form").addEventListener("change", (event) => window.__changes.push(event.target.value));
  });
  await page.click(trigger);
  await waitOpen(page);
  await option(page, "Grapes").click();
  await waitClosed(page);
  assert.equal(await page.locator(native).inputValue(), "grapes");
  assert.deepEqual(await page.evaluate(() => window.__changes), ["grapes"]);
  assert.equal(await page.evaluate(() => new FormData(document.querySelector("form")).get("fruit")), "grapes");
});

browserTest("select: a native change (autofill) sets the value", async ({ open }) => {
  const page = await open("form__native-select");
  await record(page);
  assert.equal(await valueText(page), "Select a fruit", "precondition: placeholder");
  await page.locator(native).selectOption("banana", { force: true });
  await settle(page);
  assert.equal(await valueText(page), "Banana");
  assert.deepEqual((await events(page, "value-change")).map((e) => e.detail), [{ value: "banana" }]);
});

browserTest("select: required and disabled reach the native select", async ({ open }) => {
  const page = await open("form__required-disabled-native");
  assert.deepEqual(await page.locator(native).evaluate((el) => [el.required, el.disabled]), [true, true]);
  assert.equal(await page.locator(trigger).getAttribute("aria-required"), "true");
  const plain = await open("form__native-select");
  assert.deepEqual(await plain.locator(native).evaluate((el) => [el.required, el.disabled]), [false, false]);
});

browserTest("select: form reset restores the initial value", async ({ open }) => {
  const page = await open("form__reset-restores-initial");
  await page.click(trigger);
  await waitOpen(page);
  await option(page, "Grapes").click();
  await waitClosed(page);
  assert.equal(await valueText(page), "Grapes", "precondition: changed");
  assert.equal(await page.locator(native).inputValue(), "grapes");
  await page.getByRole("button", { name: "Reset" }).click();
  await page.waitForFunction((selector) => document.querySelector(selector).textContent === "Apple", value);
  assert.equal(await page.locator(native).inputValue(), "apple");
});

browserTest("select: removing the host while open leaves nothing behind and a reinserted host opens again", async ({ open }) => {
  const page = await open("open__click");
  await openWith(page);
  assert.equal(await page.locator(content).count(), 1, "precondition: open");
  await page.evaluate(async (selector) => {
    const host = document.querySelector(selector);
    window.__parked = { host, parent: host.parentNode, next: host.nextSibling };
    host.remove();
    await new Promise((resolve) => setTimeout(resolve));
  }, HOST);
  await settle(page);
  assert.equal(await page.locator(content).count(), 0);
  assert.deepEqual(await bodyEffects(page), RELEASED);
  await page.evaluate(async () => {
    const { host, parent, next } = window.__parked;
    parent.insertBefore(host, next);
    await new Promise((resolve) => setTimeout(resolve));
  });
  await settle(page);
  await openWith(page);
  await waitFocused(page, "Apple");
  await page.keyboard.press("Escape");
  await waitClosed(page);
  assert.deepEqual(await bodyEffects(page), RELEASED);
});

browserTest("select: the Turbo snapshot has nothing open and the restored select connects closed and opens again", async ({ open }) => {
  const page = await open("open__click");
  await openWith(page);
  const snapshot = await page.evaluate(async (selector) => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve));
    return { contents: document.querySelectorAll("[data-slot=select-content]").length, html: document.querySelector(selector).parentElement.innerHTML };
  }, HOST);
  assert.equal(snapshot.contents, 0);
  assert.deepEqual(await bodyEffects(page), RELEASED, "the snapshot body has no lock, guards or aria-hidden");
  await page.evaluate(({ selector, html }) => { document.querySelector(selector).parentElement.innerHTML = html; }, { selector: HOST, html: snapshot.html });
  await settle(page);
  assert.equal(await triggerState(page), "closed");
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false");
  assert.equal(await page.locator(content).count(), 0);
  await openWith(page);
  await waitFocused(page, "Apple");
  assert.equal((await bodyEffects(page)).scrollLocked, true);
});
