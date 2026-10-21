import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// Combobox (Base UI re-implemented in the shadcn--combobox controller). What the parity runner cannot express: the events and
// their cancelable defaults, controlled values, the scorer behind the default filter, the hidden inputs a native form submits, the
// Turbo snapshot and the cleanup on disconnect. Keyboard, pointer, chips, popup and placement parity against Base UI itself is
// covered by the scenarios (G2/G3).
browserTest.component = "combobox";
const input = "[data-slot=input-group-control]";
const chipInput = "[data-slot=combobox-chip-input]";
const host = "[data-controller~='shadcn--combobox']";
const popup = "[data-slot=combobox-content]";
const portal = "[data-base-ui-portal]";
const item = "[data-slot=combobox-item]";

const press = async (page, key) => { await page.keyboard.press(key); await settle(page); };
const type = async (page, text) => { await page.keyboard.type(text); await settle(page); };
const items = (page) => page.locator(item).evaluateAll((els) => els.map((el) => el.textContent.trim()));
const highlighted = (page) => page.evaluate(() => document.querySelector("[data-slot=combobox-item][data-highlighted]")?.textContent.trim());
const hidden = (page) => page.evaluate(() => [...document.querySelectorAll("[data-shadcn--combobox-part=hidden-input], [data-shadcn--combobox-part=form-value]")].map((el) => el.value));
const controller = (page) => page.evaluate(() => window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~='shadcn--combobox']"), "shadcn--combobox").selected);

// Records the public events of the controller (name, detail, whether cancelable) in window.__events; `prevent` names are cancelled.
const record = (page, { prevent = [] } = {}) => page.evaluate((prevent) => {
  window.__events = [];
  for (const name of ["value-change", "open-change", "input-value-change", "item-highlighted", "open-change-complete"]) {
    document.addEventListener(`shadcn--combobox:${name}`, (event) => {
      window.__events.push({ name, detail: event.detail, cancelable: event.cancelable, slot: event.target.dataset.controller });
      if (prevent.includes(name)) event.preventDefault();
    });
  }
}, prevent);
const events = (page, name) => page.evaluate((name) => window.__events.filter((e) => !name || e.name === name), name);

// What Turbo's snapshot would contain after turbo:before-cache; the restore re-inserts the host markup, which connects a new controller.
const snapshot = (page) => page.evaluate(async () => {
  document.dispatchEvent(new Event("turbo:before-cache"));
  await new Promise((resolve) => setTimeout(resolve));
  return document.querySelector("[data-controller~='shadcn--combobox']").outerHTML;
});
const restore = async (page, html) => {
  await page.evaluate((html) => {
    const live = document.querySelector("[data-controller~='shadcn--combobox']");
    live.insertAdjacentHTML("afterend", html);
    live.remove();
  }, html);
  await settle(page);
};

browserTest("combobox: the default filter is the fuzzy scorer, ranked; groups and Empty follow the matches", async ({ open }) => {
  const page = await open("default__open-click");
  await page.click(input);
  await type(page, "nxt");
  assert.deepEqual(await items(page), ["Next.js", "Nuxt.js"], "a subsequence matches and prefix/boundary matches rank first");
  await page.fill(input, "x");
  await settle(page);
  assert.deepEqual((await items(page)).sort(), ["Next.js", "Nuxt.js", "Remix"]);
  await page.fill(input, "zz");
  await settle(page);
  assert.deepEqual(await items(page), []);
  assert.equal(await page.locator("[data-slot=combobox-empty]").textContent(), "No items found.");
  assert.equal(await page.locator(input).getAttribute("data-list-empty"), "");
  assert.equal(await page.locator(popup).getAttribute("data-empty"), "");
});

browserTest("combobox: groups are dropped when none of their items match", async ({ open }) => {
  const page = await open("filter__groups-no-match");
  await page.click(input);
  assert.equal(await page.locator("[data-slot=combobox-group]").count(), 3);
  await type(page, "lond");
  assert.equal(await page.locator("[data-slot=combobox-group]").count(), 1);
  assert.deepEqual(await items(page), ["(GMT+0) London"]);
  assert.equal(await page.locator("[data-slot=combobox-label]").textContent(), "Europe");
  await page.fill(input, "");
  await settle(page);
  assert.equal(await page.locator("[data-slot=combobox-group]").count(), 3);
});

browserTest("combobox: filter nil shows every item and limit caps the rendered matches", async ({ open }) => {
  const unfiltered = await open("filter__null-shows-all");
  await unfiltered.click(input);
  await type(unfiltered, "zz");
  assert.equal((await items(unfiltered)).length, 5);
  const limited = await open("filter__limit");
  await limited.click(input);
  assert.deepEqual(await items(limited), ["Next.js", "SvelteKit"]);
});

browserTest("combobox: with the fuzzy filter limit applies after ranking, so the best matches are kept", async ({ open }) => {
  const page = await open("filter__limit");
  await page.click(input);
  await type(page, "s");
  assert.deepEqual(await items(page), ["SvelteKit", "Astro"], "source order would cut the better matches: Next.js, SvelteKit");
});

browserTest("combobox: the contains filter is Base UI's collator substring match, in source order", async ({ open }) => {
  const page = await open("default__open-click");
  await page.evaluate(() => {
    const instance = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller~='shadcn--combobox']"), "shadcn--combobox");
    instance.cfg = { ...instance.cfg, filter: "contains" };
  });
  await page.click(input);
  await type(page, "nxt");
  assert.deepEqual(await items(page), [], "no subsequence matching");
  await page.fill(input, "");
  await type(page, "JS");
  assert.deepEqual(await items(page), ["Next.js", "Nuxt.js"], "case-insensitive substring, punctuation ignored, source order");
});

browserTest("combobox: typing opens the popup, the list scrolls back to the top and the first match is highlighted with auto_highlight", async ({ open }) => {
  const page = await open("example__combobox-auto-highlight");
  await page.focus(input);
  assert.equal(await page.locator(popup).count(), 0, "focus alone does not open");
  await type(page, "a");
  assert.equal(await page.locator(popup).count(), 1);
  assert.equal((await items(page)).length > 0, true);
  assert.equal(await highlighted(page), (await items(page))[0]);
  assert.equal(await page.locator(input).getAttribute("aria-activedescendant"), await page.locator(`${item}[data-highlighted]`).getAttribute("id"));
});

browserTest("combobox: Enter on a highlighted item selects and closes; without a highlight it closes and leaves the form to submit", async ({ open }) => {
  const page = await open("default__open-click");
  await record(page);
  await page.focus(input);
  await press(page, "ArrowDown");
  assert.equal(await highlighted(page), "Next.js");
  await press(page, "Enter");
  assert.equal(await page.locator(input).inputValue(), "Next.js");
  assert.equal(await page.locator(popup).count(), 0);
  assert.deepEqual((await events(page, "value-change")).map((e) => [e.detail, e.cancelable]), [[{ value: "Next.js", reason: "item-press" }, true]]);
  await press(page, "ArrowDown");
  assert.equal(await highlighted(page), "Next.js", "the selected item is highlighted when the popup opens");
});

browserTest("combobox: value-change is cancelable (the selection stays) and open-change can keep the popup closed", async ({ open }) => {
  const page = await open("default__open-click");
  await record(page, { prevent: ["value-change"] });
  await page.click(input);
  await page.click("role=option[name=Remix]");
  assert.equal(await page.locator(input).inputValue(), "", "the text only follows an accepted change");
  assert.deepEqual(await hidden(page), [""]);
  assert.equal((await events(page, "value-change")).length, 1);

  const blocked = await open("default__open-click");
  await record(blocked, { prevent: ["open-change"] });
  await blocked.click(input);
  assert.equal(await blocked.locator(popup).count(), 0);
  assert.deepEqual((await events(blocked, "open-change")).map((e) => e.detail), [{ open: true, reason: "input-press" }]);
});

browserTest("combobox: events carry the Base UI reasons and open-change-complete fires after the unmount", async ({ open }) => {
  const page = await open("default__open-click");
  await record(page);
  await page.click(input);
  await press(page, "ArrowDown");
  await press(page, "Escape");
  assert.deepEqual((await events(page, "open-change")).map((e) => [e.detail.open, e.detail.reason]), [[true, "input-press"], [false, "escape-key"]]);
  assert.deepEqual((await events(page, "item-highlighted")).map((e) => [e.detail.value, e.detail.index, e.detail.reason, e.cancelable]),
    [["Next.js", 0, "keyboard", false], [undefined, -1, "none", false]]);
  assert.deepEqual((await events(page, "open-change-complete")).map((e) => [e.detail, e.cancelable]), [[{ open: false }, false]]);
  await page.click(input);
  await settle(page);
  await page.mouse.click(5, 5);
  await settle(page);
  assert.equal((await events(page, "open-change")).at(-1).detail.reason, "outside-press");
  await page.click(input);
  await type(page, "x");
  assert.deepEqual((await events(page, "input-value-change")).at(-1).detail, { inputValue: "x", reason: "input-change" });
});

browserTest("combobox: a controlled value fires the event but keeps the selection; the attribute moves it", async ({ open }) => {
  const page = await open("selected__controlled-value");
  await record(page);
  await page.click(input);
  await page.click("role=option[name=Remix]");
  assert.deepEqual((await events(page, "value-change")).map((e) => e.detail.value), ["Remix"]);
  assert.deepEqual(await controller(page), ["Astro"]);
  assert.deepEqual(await hidden(page), ["Astro"]);
  assert.equal(await page.locator(input).inputValue(), "Astro", "the controlled label comes back once the popup unmounted");
  await page.locator(host).evaluate((el) => el.setAttribute("data-shadcn--combobox-selected-value", '["Nuxt.js"]'));
  await settle(page);
  assert.deepEqual(await hidden(page), ["Nuxt.js"]);
});

browserTest("combobox: a controlled open keeps its state and follows the attribute", async ({ open }) => {
  const page = await open("default__controlled-open");
  await record(page);
  assert.equal(await page.locator(popup).count(), 1);
  await page.focus(input);
  await press(page, "Escape");
  assert.equal(await page.locator(popup).count(), 1, "the caller owns the state");
  assert.deepEqual((await events(page, "open-change")).map((e) => e.detail), [{ open: false, reason: "escape-key" }]);
  await page.locator(host).evaluate((el) => el.setAttribute("data-shadcn--combobox-open-value", "false"));
  await settle(page);
  assert.equal(await page.locator(popup).count(), 0);
});

browserTest("combobox: disabled opens nothing and read_only browses without selecting", async ({ open }) => {
  const disabled = await open("disabled__root");
  await disabled.locator(input).click({ force: true });
  await disabled.locator("[data-slot=input-group-button]").dispatchEvent("mousedown");
  assert.equal(await disabled.locator(popup).count(), 0);

  const readOnly = await open("readonly__open-no-select");
  await readOnly.click(input);
  assert.equal(await readOnly.locator(popup).count(), 1);
  await press(readOnly, "ArrowUp");
  await press(readOnly, "Enter");
  assert.deepEqual(await hidden(readOnly), ["Astro"]);
  assert.equal(await readOnly.locator(popup).count(), 1, "Enter on a highlighted item does not even close it");
  await readOnly.click("role=option[name=Remix]");
  assert.deepEqual(await hidden(readOnly), ["Astro"]);
});

browserTest("combobox: Escape on a closed input clears the text and the selection", async ({ open }) => {
  const page = await open("selected__default-value");
  await record(page);
  await page.focus(input);
  await press(page, "Escape");
  assert.equal(await page.locator(input).inputValue(), "");
  assert.deepEqual(await hidden(page), [""]);
  assert.deepEqual((await events(page, "value-change")).map((e) => e.detail), [{ value: null, reason: "escape-key" }]);
});

browserTest("combobox: clearing the text clears the selection and the clear button follows", async ({ open }) => {
  const page = await open("example__combobox-with-clear");
  assert.equal(await page.locator("[data-slot=combobox-clear]").count(), 1);
  await page.click("[data-slot=combobox-clear]");
  await page.waitForFunction(() => document.querySelectorAll("[data-slot=combobox-clear]").length === 0);
  assert.equal(await page.locator(input).inputValue(), "");
  assert.deepEqual(await hidden(page), [""]);
  assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "input-group-control");
  await page.click(input);
  await page.click("role=option[name=Remix]");
  assert.equal(await page.locator("[data-slot=combobox-clear]").count(), 1);
  assert.equal(await page.locator("[data-slot=combobox-clear]").getAttribute("data-visible"), "");
});

browserTest("combobox: a single selection submits in a native form, with the serialized value of object items", async ({ open }) => {
  const page = await open("form__object-items-submit-value");
  await page.click(input);
  await page.click("role=option[name=Remix]");
  const submitted = () => page.evaluate(() => [...new FormData(document.querySelector("form")).entries()]);
  assert.deepEqual(await submitted(), [["framework", "remix"]]);
  assert.equal(await page.locator(input).inputValue(), "Remix");
});

browserTest("combobox: a multiple selection submits one value per chip, in selection order, and chips follow", async ({ open }) => {
  const page = await open("form__multiple-hidden-inputs");
  const submitted = () => page.evaluate(() => new FormData(document.querySelector("form")).getAll("frameworks"));
  assert.deepEqual(await submitted(), ["Next.js", "Remix"]);
  await page.click(chipInput);
  await page.click("role=option[name=Astro]");
  assert.deepEqual(await submitted(), ["Next.js", "Remix", "Astro"]);
  assert.equal(await page.locator(popup).count(), 1, "multiple keeps the popup open");
  assert.deepEqual(await page.locator("[data-slot=combobox-chip]").evaluateAll((els) => els.map((el) => el.firstChild.textContent)), ["Next.js", "Remix", "Astro"]);
  await page.click("role=option[name=Next.js]");
  assert.deepEqual(await submitted(), ["Remix", "Astro"]);
  await page.locator("[data-slot=combobox-chip-remove] >> nth=0").click();
  assert.deepEqual(await submitted(), ["Astro"]);
  assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "combobox-chip-input");
});

browserTest("combobox: Backspace on an empty chips input removes the last chip; ArrowLeft focuses the chips", async ({ open }) => {
  const page = await open("multiple__arrow-left-focuses-chips");
  await page.focus(chipInput);
  await press(page, "ArrowLeft");
  assert.equal(await page.evaluate(() => document.activeElement.textContent.trim()), "Remix");
  await press(page, "ArrowLeft");
  assert.equal(await page.evaluate(() => document.activeElement.textContent.trim()), "Next.js");
  await press(page, "Delete");
  assert.deepEqual(await hidden(page), [""]);
  assert.equal(await page.locator("[data-slot=combobox-chip]").count(), 1);
  assert.equal(await page.evaluate(() => document.activeElement.textContent.trim()), "Remix", "the focus lands on the chip now at that index");
  await press(page, "Backspace");
  assert.equal(await page.locator("[data-slot=combobox-chip]").count(), 0);
  assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "combobox-chip-input");
  assert.equal(await page.locator("[data-slot=combobox-chips]").getAttribute("role"), null);
});

browserTest("combobox: a standalone trigger selects by typing without opening and returns focus when the popup closes", async ({ open }) => {
  const page = await open("popup__closed-trigger-typeahead");
  await page.keyboard.press("Tab");
  await page.keyboard.type("n");
  assert.deepEqual(await controller(page), ["Next.js"]);
  assert.equal(await page.locator(popup).count(), 0);
  await page.keyboard.press("ArrowDown");
  await page.waitForSelector(popup);
  await settle(page);
  assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "input-group-control", "focus moves into the search field");
  assert.equal(await page.locator("[data-slot=combobox-trigger]").getAttribute("aria-controls"), await page.locator(popup).getAttribute("id"));
  await press(page, "Escape");
  assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "combobox-trigger");
});

browserTest("combobox: Enter and Space on the tabbed standalone trigger open the popup and focus the search field", async ({ open }) => {
  const page = await open("popup__keyboard-enter-opens");
  for (const key of ["Enter", "Space"]) {
    await page.evaluate(() => document.querySelector("[data-slot=combobox-trigger]").focus());
    await press(page, key);
    assert.equal(await page.locator(popup).count(), 1, `${key} opens`);
    assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "input-group-control", `${key} focuses the search field`);
    await press(page, "Escape");
    assert.equal(await page.locator(popup).count(), 0);
  }
});

browserTest("combobox: while open everything outside is aria-hidden and the page marked inert; both are restored on close", async ({ open }) => {
  const page = await open("default__open-click");
  const state = () => page.evaluate(() => ({
    hidden: document.querySelectorAll("[aria-hidden=true]").length,
    inert: document.querySelectorAll("[data-base-ui-inert]").length,
    addon: document.querySelector("[data-slot=input-group-addon]").getAttribute("aria-hidden"),
    marker: document.querySelectorAll("[data-aria-hidden]").length
  }));
  const before = await state();
  await page.click(input);
  const opened = await state();
  assert.equal(opened.addon, "true");
  assert.ok(opened.hidden > before.hidden && opened.inert > before.inert);
  assert.equal(opened.marker, 0, "Base UI marks with aria-hidden and data-base-ui-inert only");
  await press(page, "Escape");
  assert.deepEqual(await state(), before);
});

browserTest("combobox: a modal popup locks the page scroll and closes on a backdrop press", async ({ open }) => {
  const page = await open("modal__outside-click-closes");
  await page.click(input);
  // The dismissable layer arms its outside-press listener one task after the popup opens (Radix parity); the lock and the backdrop
  // are there at once, so asserting them does not prove the press will be heard. settle() queues a zero-delay timer behind it.
  await settle(page);
  assert.equal(await page.evaluate(() => document.body.hasAttribute("data-scroll-locked")), true);
  assert.equal(await page.locator("div[role=presentation][aria-hidden=true]").count(), 1);
  await page.mouse.click(5, 5);
  await settle(page);
  assert.equal(await page.locator(popup).count(), 0);
  assert.equal(await page.evaluate(() => document.body.hasAttribute("data-scroll-locked")), false);
});

browserTest("combobox: the Turbo snapshot is closed with the current selection and the restored page works", async ({ open }) => {
  const page = await open("form__select-updates-hidden-input");
  await page.click(input);
  await page.click("role=option[name=Nuxt.js]");
  await page.click(input);
  const html = await snapshot(page);
  assert.equal(await page.locator(portal).count(), 0, "the popup is not part of the snapshot");
  assert.equal(await page.locator("[data-base-ui-inert]").count(), 0);
  assert.equal(await page.locator("[data-slot=input-group-addon]").getAttribute("aria-hidden"), null);
  assert.equal(await page.locator(input).getAttribute("aria-expanded"), "false");
  await restore(page, html);
  assert.equal(await page.locator(input).inputValue(), "Nuxt.js");
  assert.deepEqual(await hidden(page), ["Nuxt.js"]);
  assert.deepEqual(await controller(page), ["Nuxt.js"]);
  await page.click(input);
  assert.equal(await page.locator(popup).count(), 1);
  assert.equal(await page.locator(`${item}[aria-selected=true]`).textContent(), "Nuxt.js");
  await page.click("role=option[name=Astro]");
  assert.deepEqual(await hidden(page), ["Astro"]);
});

browserTest("combobox: the Turbo snapshot of a multiple combobox keeps its chips and hidden values", async ({ open }) => {
  const page = await open("form__multiple-hidden-inputs");
  await page.click(chipInput);
  await page.click("role=option[name=Astro]");
  const html = await snapshot(page);
  await restore(page, html);
  assert.deepEqual(await page.locator("[data-slot=combobox-chip]").evaluateAll((els) => els.map((el) => el.firstChild.textContent)), ["Next.js", "Remix", "Astro"]);
  assert.deepEqual(await page.evaluate(() => new FormData(document.querySelector("form")).getAll("frameworks")), ["Next.js", "Remix", "Astro"]);
  await page.click("[data-slot=combobox-chip-remove] >> nth=1");
  assert.deepEqual(await page.evaluate(() => new FormData(document.querySelector("form")).getAll("frameworks")), ["Next.js", "Astro"]);
  assert.equal(await page.locator("[data-slot=combobox-chip]").count(), 2);
});

browserTest("combobox: removing the host while open releases the portal, aria-hidden and the scroll lock", async ({ open }) => {
  const page = await open("modal__open-backdrop");
  await page.click(input);
  assert.equal(await page.locator(portal).count(), 1);
  await page.locator(host).evaluate((el) => el.remove());
  await settle(page);
  assert.equal(await page.locator(portal).count(), 0);
  assert.equal(await page.evaluate(() => document.body.hasAttribute("data-scroll-locked")), false);
  assert.equal(await page.locator("[aria-hidden=true], [data-base-ui-inert]").count(), 0);
});

browserTest("combobox: static children are never filtered and the list reports itself empty", async ({ open }) => {
  const page = await open("static__children-without-items");
  await page.click(input);
  await type(page, "ban");
  assert.deepEqual(await items(page), ["Apple", "Banana"]);
  assert.equal(await page.locator(input).getAttribute("data-list-empty"), "");
  assert.equal((await page.locator("[data-slot=combobox-empty]").textContent()).replace("\u2060", ""), "No items found.");
});

browserTest("combobox: native autofill of the hidden input selects the matching item", async ({ open }) => {
  const page = await open("form__select-updates-hidden-input");
  await record(page);
  await page.locator("[data-shadcn--combobox-part=hidden-input]").evaluate((el) => {
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(el, "remix");
    el.dispatchEvent(new Event("change", { bubbles: true }));
  });
  await settle(page);
  assert.deepEqual(await controller(page), ["Remix"]);
  assert.equal(await page.locator(input).inputValue(), "Remix");
  assert.deepEqual((await events(page, "value-change")).map((e) => e.detail), [{ value: "Remix", reason: "none" }]);
});

browserTest("combobox: Tab out of the input closes the popup and restores the selected label", async ({ open }) => {
  const page = await open("keyboard__tab-closes");
  await page.focus(input);
  await type(page, "re");
  assert.equal(await page.locator(popup).count(), 1);
  await press(page, "Tab");
  assert.equal(await page.locator(popup).count(), 0);
  assert.equal(await page.locator(input).inputValue(), "Astro");
  assert.equal(await page.evaluate(() => document.activeElement.textContent), "Next");
});
