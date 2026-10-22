import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// Command (cmdk re-implemented in the chadcn--command controller). What the parity runner cannot express: the three events and
// their detail, a JS filter function, IME composition, items appended later (Turbo Stream) and cleanup before the Turbo cache.
// Filtering, sorting, keyboard and dialog parity against cmdk itself is covered by the scenarios (G2/G3).
browserTest.component = "command";
const input = "[data-slot=command-input]";
const root = "[data-slot=command]";
const item = "[cmdk-item]";
const texts = (page, selector = item) => page.locator(selector).evaluateAll((els) => els.map((el) => el.textContent.trim()));
const selected = (page) => page.evaluate(() => document.querySelector('[cmdk-item][aria-selected="true"]')?.textContent.trim());
const search = async (page, value) => { await page.fill(input, value); await settle(page); };
const press = async (page, key) => { await page.keyboard.press(key); await settle(page); };

// Records the public events of the controller (name, detail, target slot) in window.__events.
const record = (page) => page.evaluate(() => {
  window.__events = [];
  for (const name of ["value-change", "search-change", "select"]) {
    document.addEventListener(`chadcn--command:${name}`, (event) => window.__events.push({ name, detail: event.detail, slot: event.target.dataset.slot, cancelable: event.cancelable }));
  }
});
const events = (page) => page.evaluate(() => window.__events);

browserTest("command: the first enabled item is selected on connect, aria-activedescendant is absent until the selection moves", async ({ open }) => {
  const page = await open("default__rest");
  assert.equal(await selected(page), "Calendar");
  assert.equal(await page.locator(input).getAttribute("aria-activedescendant"), null);
  await page.focus(input);
  await press(page, "ArrowDown");
  const id = await page.locator('[cmdk-item][aria-selected="true"]').getAttribute("id");
  assert.equal(await selected(page), "Search Emoji");
  assert.equal(await page.locator(input).getAttribute("aria-activedescendant"), id);
  assert.equal(await page.locator("[cmdk-list]").getAttribute("aria-activedescendant"), id);
});

browserTest("command: arrow keys skip disabled items, stay at the ends and Enter dispatches select with the value", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  await page.focus(input);
  await press(page, "ArrowDown");
  await press(page, "ArrowDown");
  assert.equal(await selected(page), "Profile⌘P", "Calculator is disabled and skipped");
  await press(page, "End");
  await press(page, "ArrowDown");
  assert.equal(await selected(page), "Settings⌘S");
  await press(page, "Enter");
  const log = (await events(page)).filter((e) => e.name === "select");
  assert.deepEqual(log.map((e) => [e.detail.value, e.slot, e.cancelable]), [["Settings⌘S", "command-item", false]]);
});

browserTest("command: clicking an enabled item selects it and dispatches select; a disabled item does nothing", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  await page.click("text=Billing");
  assert.equal(await selected(page), "Billing⌘B");
  await page.click("text=Calculator", { force: true });
  assert.equal(await selected(page), "Billing⌘B");
  assert.deepEqual((await events(page)).filter((e) => e.name === "select").map((e) => e.detail.value), ["Billing⌘B"]);
});

browserTest("command: typing filters and ranks the items, hides groups without a match and shows Empty only for no match", async ({ open }) => {
  const page = await open("default__rest");
  await search(page, "cal");
  assert.deepEqual(await texts(page), ["Calculator", "Calendar"], "enabled items are sorted after the disabled one, which never moves");
  assert.equal(await selected(page), "Calendar");
  assert.equal(await page.locator("[cmdk-separator]").count(), 0, "separators only show for an empty search");
  assert.equal(await page.locator("[cmdk-group][hidden]").count(), 1);
  await search(page, "zzz");
  assert.equal(await page.locator("[cmdk-empty]").count(), 1);
  assert.equal(await page.locator("[cmdk-empty]").textContent(), "No results found.");
  assert.equal(await selected(page), undefined);
  await search(page, "");
  assert.equal(await page.locator("[cmdk-empty]").count(), 0);
  assert.equal(await page.locator("[cmdk-group][hidden]").count(), 0);
  assert.equal(await page.locator("[cmdk-separator]").count(), 1);
  assert.equal((await texts(page)).length, 6);
});

browserTest("command: keywords are matched", async ({ open }) => {
  const page = await open("filter__keywords");
  await search(page, "agenda");
  assert.deepEqual(await texts(page), ["Calendar"]);
});

browserTest("command: search-change fires on every input with the typed value; a controlled input keeps its value", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  await page.focus(input);
  await page.keyboard.type("ca");
  assert.deepEqual((await events(page)).filter((e) => e.name === "search-change").map((e) => [e.detail.value, e.slot]), [["c", "command-input"], ["ca", "command-input"]]);

  const controlled = await open("filter__input-controlled-value");
  await record(controlled);
  assert.equal(await controlled.locator(input).inputValue(), "cal");
  await controlled.focus(input);
  await controlled.keyboard.type("x");
  await settle(controlled);
  assert.equal(await controlled.locator(input).inputValue(), "cal", "React restores a controlled value");
  assert.deepEqual((await events(controlled)).map((e) => [e.name, e.detail.value]), [["search-change", "xcal"]]);
  assert.deepEqual(await texts(controlled), ["Calculator", "Calendar"]);
});

browserTest("command: a controlled search follows its attribute", async ({ open }) => {
  const page = await open("filter__input-controlled-value");
  await page.locator(input).evaluate((el) => el.setAttribute("data-chadcn--command-search", "set"));
  await settle(page);
  assert.equal(await page.locator(input).inputValue(), "set");
  assert.deepEqual(await texts(page), ["Settings⌘S"]);
});

browserTest("command: value-change is dispatched only for a controlled root, with the new value", async ({ open }) => {
  const page = await open("value__controlled-trimmed");
  await record(page);
  assert.equal(await selected(page), "Billing");
  await page.focus(input);
  await press(page, "ArrowDown");
  assert.deepEqual((await events(page)).filter((e) => e.name === "value-change").map((e) => e.detail.value), ["settings"]);
  assert.equal(await selected(page), "Settings");

  const uncontrolled = await open("default__rest");
  await record(uncontrolled);
  await uncontrolled.focus(input);
  await press(uncontrolled, "ArrowDown");
  assert.equal((await events(uncontrolled)).filter((e) => e.name === "value-change").length, 0);
});

browserTest("command: a controlled value fed back through the attribute moves the selection", async ({ open }) => {
  const page = await open("value__controlled-trimmed");
  await page.locator(root).evaluate((el) => el.setAttribute("data-chadcn--command-value-value", " profile "));
  await settle(page);
  assert.equal(await selected(page), "Profile");
});

browserTest("command: a custom filter function assigned on the controller replaces the scorer", async ({ open }) => {
  const page = await open("default__rest");
  await page.evaluate(() => {
    const controller = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-slot=command]"), "chadcn--command");
    controller.filter = (value, search) => (value.toLowerCase().startsWith(search.toLowerCase()) ? 1 : 0);
  });
  await search(page, "al");
  assert.equal((await texts(page)).length, 0, "no value starts with al (the scorer would match Calendar)");
  await search(page, "cal");
  assert.deepEqual(await texts(page), ["Calendar", "Calculator"], "equal scores keep the source order");
});

browserTest("command: keys pressed while composing (IME) are ignored, keys already handled are ignored", async ({ open }) => {
  const page = await open("default__rest");
  const before = await selected(page);
  await page.locator(input).evaluate((el) => {
    el.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true, isComposing: true }));
    el.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", keyCode: 229, bubbles: true }));
  });
  await settle(page);
  assert.equal(await selected(page), before);
});

browserTest("command: Ctrl+n moves down with vim bindings, and is not prevented without them", async ({ open }) => {
  const page = await open("keyboard__vim-bindings-false");
  const prevented = () => page.locator(input).evaluate((el) => {
    const event = new KeyboardEvent("keydown", { key: "n", ctrlKey: true, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  });
  const before = await selected(page);
  assert.equal(await prevented(), false);
  assert.equal(await selected(page), before);

  const vim = await open("default__rest");
  await vim.focus(input);
  await vim.keyboard.press("Control+n");
  await settle(vim);
  assert.equal(await selected(vim), "Search Emoji");
});

browserTest("command: items added after connect (Turbo Stream) are registered, filtered and selectable", async ({ open }) => {
  const page = await open("default__rest");
  await page.locator("[cmdk-group-items]").first().evaluate((el) => {
    el.insertAdjacentHTML("beforeend", '<div data-slot="command-item" cmdk-item="" role="option" aria-disabled="false" aria-selected="false" data-disabled="false" data-selected="false">Zebra</div>');
  });
  await settle(page);
  await search(page, "zeb");
  assert.deepEqual(await texts(page), ["Zebra"]);
  assert.equal(await selected(page), "Zebra");
  assert.ok(await page.locator('[cmdk-item][aria-selected="true"]').getAttribute("id"), "an id was generated");
  await search(page, "");
  assert.ok((await texts(page)).includes("Zebra"));
});

browserTest("command: Alt+ArrowDown jumps to the next group and Meta+ArrowUp to the first item", async ({ open }) => {
  const page = await open("default__rest");
  await page.focus(input);
  await press(page, "Alt+ArrowDown");
  assert.equal(await selected(page), "Profile⌘P");
  await press(page, "Meta+ArrowUp");
  assert.equal(await selected(page), "Calendar");
});

browserTest("command: the state before the Turbo cache is restored to the server render", async ({ open }) => {
  const page = await open("default__rest");
  await search(page, "bil");
  assert.equal((await texts(page)).length, 1);
  await page.evaluate(() => document.dispatchEvent(new Event("turbo:before-cache")));
  assert.equal(await page.locator(input).inputValue(), "");
  assert.equal((await texts(page)).length, 6);
  assert.deepEqual(await texts(page, "[cmdk-item]"), ["Calendar", "Search Emoji", "Calculator", "Profile⌘P", "Billing⌘B", "Settings⌘S"]);
  assert.equal(await page.locator("[cmdk-group][hidden]").count(), 0);
  assert.equal(await page.locator('[cmdk-item][aria-selected="true"]').count(), 0);
  assert.equal(await page.locator(input).getAttribute("aria-activedescendant"), null);
});

browserTest("command: disconnect restores the server list and stops listening", async ({ open }) => {
  const page = await open("default__rest");
  await search(page, "zzz");
  assert.equal(await page.locator("[cmdk-empty]").count(), 1);
  await page.locator(root).evaluate((el) => { el.dataset.controller = ""; });
  await settle(page);
  assert.equal(await page.locator("[cmdk-empty]").count(), 0);
  assert.equal(await page.locator("[cmdk-group][hidden]").count(), 0);
  assert.equal((await texts(page)).length, 6);
  await page.locator(input).fill("cal");
  await settle(page);
  assert.equal((await texts(page)).length, 6, "no controller reacts to the input any more");
});

browserTest("command: an item removed like a Turbo Stream stays removed after the cache reset and the query filters again", async ({ open }) => {
  const page = await open("default__rest");
  await search(page, "bil");
  await page.evaluate(() => document.querySelector('[cmdk-item][data-value="Billing⌘B"]').remove());
  await settle(page);
  await page.evaluate(() => document.dispatchEvent(new Event("turbo:before-cache")));
  assert.deepEqual(await texts(page), ["Calendar", "Search Emoji", "Calculator", "Profile⌘P", "Settings⌘S"]);
  await search(page, "cal");
  assert.equal((await texts(page)).length, 2);
  await search(page, "bil");
  assert.equal((await texts(page)).length, 0);
});

browserTest("command: the same query filters again after the cache reset", async ({ open }) => {
  const page = await open("default__rest");
  await search(page, "bil");
  await page.evaluate(() => document.dispatchEvent(new Event("turbo:before-cache")));
  await search(page, "bil");
  assert.equal((await texts(page)).length, 1);
});

browserTest("command: a group added after connect keeps its place after the cache reset", async ({ open }) => {
  const page = await open("default__rest");
  const before = await page.locator("[cmdk-group]").evaluateAll((els) => els.map((el) => el.dataset.value));
  await page.evaluate(() => {
    const groups = document.querySelectorAll("[cmdk-group]");
    const last = groups[groups.length - 1];
    const clone = last.cloneNode(true);
    clone.dataset.value = "Late";
    clone.querySelectorAll("[cmdk-item]").forEach((el) => { el.removeAttribute("id"); el.dataset.value = `Late ${el.dataset.value}`; });
    last.after(clone);
  });
  await settle(page);
  await search(page, "zzz");
  await page.evaluate(() => document.dispatchEvent(new Event("turbo:before-cache")));
  const after = await page.locator("[cmdk-group]").evaluateAll((els) => els.map((el) => el.dataset.value));
  assert.deepEqual(after, [...before, "Late"]);
});

browserTest("command: dialog variant mounts a fresh command on every open", async ({ open }) => {
  const page = await open("dialog__default-open");
  await page.waitForSelector(input);
  await search(page, "cal");
  assert.equal((await texts(page)).length, 2);
  await page.keyboard.press("Escape");
  await page.waitForSelector(input, { state: "detached" });
});

browserTest("command: removing a group with a filter-detached separator and items does not break the next search", async ({ open }) => {
  const page = await open("default__rest");
  const errors = [];
  page.on("pageerror", (error) => errors.push(error.message));
  const total = await page.locator("[cmdk-item]").count();
  const removed = await page.evaluate(() => {
    const group = document.querySelector("[cmdk-group]");
    return group.querySelectorAll("[cmdk-item]").length;
  });
  await search(page, "zzz");
  await page.evaluate(() => document.querySelector("[cmdk-group]").remove());
  await settle(page);
  await search(page, "");
  assert.deepEqual(errors, []);
  assert.equal(await page.locator("[cmdk-item]").count(), total - removed);
  assert.equal(await page.locator("[cmdk-group][hidden]").count(), 0);
});
