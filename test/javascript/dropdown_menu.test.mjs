import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";
import { snapshot, restore, countIn } from "./turbo_support.mjs";

// chadcn--dropdown-menu against dev/port/specs/dropdown-menu.md: trigger keyboard, roving focus, typeahead, sub-menus, selection
// (checkbox/radio are controlled only, the port dispatches and never flips them), modality, the cancelable public events,
// disconnect cleanup and the Turbo snapshot.
browserTest.component = "dropdown-menu";
const CONTROLLER = "chadcn--dropdown-menu";
const trigger = "[data-slot=dropdown-menu-trigger]";
const content = "[data-slot=dropdown-menu-content]";
const subTrigger = "[data-slot=dropdown-menu-sub-trigger]";
const subContent = "[data-slot=dropdown-menu-sub-content]";

// A point on the bare page background, proven by hit-testing: never on the content, the host or anything focusable.
// (A modal layer sets body pointer-events: none, so no element can be clicked: the press has to be a coordinate.)
const backgroundPoint = (page) => page.evaluate(() => {
  const { innerWidth: width, innerHeight: height } = window;
  const corners = [[width - 8, height - 8], [8, height - 8], [width - 8, 8], [8, 8]];
  for (const [x, y] of corners) {
    const hit = document.elementFromPoint(x, y);
    if (!hit?.closest("[data-slot], [data-controller], a, button, input, select, textarea, [tabindex]")) return { x, y };
  }
  throw new Error("no bare background point in the viewport");
});
const pressOutside = async (page) => { const { x, y } = await backgroundPoint(page); await page.mouse.click(x, y); };

const openContent = (page, selector = content) => page.waitForSelector(`${selector}[data-state=open]`);
const closedContent = (page, selector = content) => page.waitForSelector(selector, { state: "detached" });

const openWithKey = async (page, key) => {
  await page.focus(trigger);
  await page.keyboard.press(key);
  await openContent(page);
  await settle(page);
};

const active = (page) => page.evaluate(() => {
  const focusedElement = document.activeElement;
  return { slot: focusedElement?.dataset?.slot ?? null, text: focusedElement?.textContent.trim() ?? null };
});

// Focus moves in a setTimeout (roving focus, typeahead), so wait for it rather than reading it at once.
const waitItemFocus = (page, text) => page.waitForFunction(
  (text) => document.activeElement?.matches?.("[role^=menuitem]") && document.activeElement.textContent.trim() === text, text
);
const waitSlotFocus = (page, slot) => page.waitForFunction((slot) => document.activeElement?.dataset?.slot === slot, slot);

// Every public event of the controller with its plain detail, the target's slot and text; `prevent` cancels some of them.
const record = (page, { prevent = [] } = {}) => page.evaluate(({ prevent }) => {
  window.__menu = [];
  window.__menuPrevent = prevent;
  if (window.__menuRecording) return;
  window.__menuRecording = true;
  const names = ["open-change", "select", "checked-change", "value-change", "escape-key-down", "pointer-down-outside",
    "focus-outside", "interact-outside", "open-auto-focus", "close-auto-focus"];
  for (const name of names) {
    document.addEventListener(`chadcn--dropdown-menu:${name}`, (event) => {
      const { open, checked, value } = event.detail ?? {};
      window.__menu.push({ name, open, checked, value, cancelable: event.cancelable, slot: event.target.dataset?.slot, text: event.target.textContent?.trim() });
      if (window.__menuPrevent.includes(name)) event.preventDefault();
    });
  }
}, { prevent });
const recorded = (page, name) => page.evaluate((name) => window.__menu.filter((entry) => !name || entry.name === name), name);

const bodyState = (page) => page.evaluate(() => ({
  pointerEvents: document.body.style.pointerEvents,
  scrollLocked: document.body.hasAttribute("data-scroll-locked"),
  hidden: document.querySelectorAll("[aria-hidden=true]").length
}));

// --- trigger keyboard ---------------------------------------------------------------------------------------------------

for (const key of ["Enter", " ", "ArrowDown"]) {
  browserTest(`dropdown-menu: ${JSON.stringify(key)} on the trigger opens the menu and focuses the first item`, async ({ open }) => {
    const page = await open("closed__default");
    assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false", "precondition: closed");
    await openWithKey(page, key);
    const menu = page.locator(content);
    assert.equal(await menu.getAttribute("role"), "menu");
    assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "true");
    assert.equal(await page.locator(trigger).getAttribute("data-state"), "open");
    assert.equal(await page.locator(trigger).getAttribute("aria-controls"), await menu.getAttribute("id"));
    await waitItemFocus(page, "Profile");
    const profile = page.locator("[role=menuitem]:text-is('Profile')");
    assert.equal(await profile.getAttribute("data-highlighted"), "");
    assert.equal(await profile.getAttribute("tabindex"), "0");
  });
}

browserTest("dropdown-menu: ArrowUp on the trigger does nothing", async ({ open }) => {
  const page = await open("closed__default");
  await page.focus(trigger);
  await page.keyboard.press("ArrowUp");
  await settle(page);
  assert.equal(await page.locator(content).count(), 0);
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false");
  // Control: the same focused trigger does open on ArrowDown.
  await page.keyboard.press("ArrowDown");
  await openContent(page);
});

browserTest("dropdown-menu: a pointer open focuses the content, not an item (no keyboard entry focus)", async ({ open }) => {
  const page = await open("closed__default");
  await page.click(trigger);
  await openContent(page);
  await waitSlotFocus(page, "dropdown-menu-content");
  await settle(page);
  assert.equal((await active(page)).slot, "dropdown-menu-content");
  assert.equal(await page.locator("[data-highlighted]").count(), 0);
});

// --- roving focus --------------------------------------------------------------------------------------------------------

browserTest("dropdown-menu: arrows move through the items without wrapping; Home/End and PageUp/PageDown jump", async ({ open }) => {
  const page = await open("closed__default");
  await openWithKey(page, "Enter");
  await waitItemFocus(page, "Profile");
  await page.keyboard.press("ArrowDown");
  await waitItemFocus(page, "Billing");
  assert.equal(await page.locator("[role=menuitem][tabindex='0']").textContent(), "Billing", "roving tab stop follows focus");
  await page.keyboard.press("End");
  await waitItemFocus(page, "Subscription");
  await page.keyboard.press("ArrowDown");
  await settle(page);
  assert.equal((await active(page)).text, "Subscription", "no wrap without loop");
  await page.keyboard.press("Home");
  await waitItemFocus(page, "Profile");
  await page.keyboard.press("ArrowUp");
  await settle(page);
  assert.equal((await active(page)).text, "Profile", "no wrap upward either");
  await page.keyboard.press("PageDown");
  await waitItemFocus(page, "Subscription");
  await page.keyboard.press("PageUp");
  await waitItemFocus(page, "Profile");
});

browserTest("dropdown-menu: loop wraps the arrows around", async ({ open }) => {
  const page = await open("keyboard__loop");
  await openWithKey(page, "Enter");
  await waitItemFocus(page, "Profile");
  await page.keyboard.press("ArrowUp");
  await waitItemFocus(page, "Subscription");
  await page.keyboard.press("ArrowDown");
  await waitItemFocus(page, "Profile");
});

browserTest("dropdown-menu: arrows skip disabled items", async ({ open }) => {
  const page = await open("keyboard__skips-disabled");
  await openWithKey(page, "Enter");
  await waitItemFocus(page, "Profile");
  await page.keyboard.press("ArrowDown");
  await waitItemFocus(page, "Team");
  await page.keyboard.press("End");
  await settle(page);
  assert.equal((await active(page)).text, "Team", "the disabled last item is never focused");
});

browserTest("dropdown-menu: ArrowUp on the content itself focuses the last item, ArrowDown the first", async ({ open }) => {
  const page = await open("closed__default");
  await page.click(trigger);
  await openContent(page);
  await waitSlotFocus(page, "dropdown-menu-content");
  await page.keyboard.press("ArrowUp");
  await waitItemFocus(page, "Subscription");
  await page.keyboard.press("Escape");
  await closedContent(page);
  await page.click(trigger);
  await waitSlotFocus(page, "dropdown-menu-content");
  await page.keyboard.press("ArrowDown");
  await waitItemFocus(page, "Profile");
});

// Non-modal: no focus trap would hold focus, so only the prevented Tab keeps it on the item (and the menu open).
browserTest("dropdown-menu: Tab inside the content is prevented, focus stays on the item", async ({ open }) => {
  const page = await open("non-modal__open");
  await openWithKey(page, "Enter");
  await waitItemFocus(page, "Profile");
  await page.evaluate(() => document.addEventListener("keydown", (event) => {
    if (event.key === "Tab") window.__tabPrevented = event.defaultPrevented;
  }));
  await page.keyboard.press("Tab");
  assert.equal(await page.evaluate(() => window.__tabPrevented), true);
  await settle(page);
  assert.deepEqual(await active(page), { slot: "dropdown-menu-item", text: "Profile" });
  assert.equal(await page.locator(content).getAttribute("data-state"), "open");
});

// --- typeahead -----------------------------------------------------------------------------------------------------------

browserTest("dropdown-menu: a repeated typeahead character cycles through the matches and skips disabled items", async ({ open }) => {
  const page = await open("typeahead__single-char");
  await openWithKey(page, "Enter");
  await waitItemFocus(page, "Apple");
  await page.keyboard.press("b");
  await waitItemFocus(page, "Banana");
  await page.keyboard.press("b");
  await waitItemFocus(page, "Blueberry"); // Blackberry is disabled
});

browserTest("dropdown-menu: a multi-character typeahead matches the prefix", async ({ open }) => {
  const page = await open("typeahead__single-char");
  await openWithKey(page, "Enter");
  await waitItemFocus(page, "Apple");
  await page.keyboard.type("av");
  await waitItemFocus(page, "Avocado");
  assert.equal(await page.locator(content).getAttribute("data-state"), "open");
});

// --- sub-menu ------------------------------------------------------------------------------------------------------------

const toShare = async (page) => {
  await openContent(page);
  await page.locator(content).focus();
  await page.keyboard.press("ArrowDown");
  await waitItemFocus(page, "New Tab");
  await page.keyboard.press("ArrowDown");
  await waitItemFocus(page, "New Window");
  await page.keyboard.press("ArrowDown");
  await waitItemFocus(page, "Share");
};

browserTest("dropdown-menu: ArrowRight opens a sub-menu on its first item; ArrowLeft closes it and focuses the sub trigger", async ({ open }) => {
  const page = await open("sub__closed");
  await toShare(page);
  assert.equal(await page.locator(subTrigger).getAttribute("aria-expanded"), "false", "precondition: sub closed");
  await page.keyboard.press("ArrowRight");
  await openContent(page, subContent);
  await waitItemFocus(page, "Email");
  assert.equal(await page.locator(subTrigger).getAttribute("aria-expanded"), "true");
  assert.equal(await page.locator(subTrigger).getAttribute("data-state"), "open");
  assert.equal(await page.locator(subTrigger).getAttribute("aria-controls"), await page.locator(subContent).getAttribute("id"));
  await page.keyboard.press("ArrowLeft");
  await closedContent(page, subContent);
  await waitItemFocus(page, "Share");
  assert.equal(await page.locator(subTrigger).getAttribute("aria-expanded"), "false");
  assert.equal(await page.locator(content).getAttribute("data-state"), "open", "the root stays open");
});

browserTest("dropdown-menu: Escape in a sub-menu closes the whole menu and returns focus to the trigger", async ({ open }) => {
  const page = await open("sub__closed");
  await toShare(page);
  await page.keyboard.press("ArrowRight");
  await waitItemFocus(page, "Email");
  await page.keyboard.press("Escape");
  await closedContent(page, subContent);
  await closedContent(page);
  await waitSlotFocus(page, "dropdown-menu-trigger");
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false");
});

// --- Escape, focus return, cancelable events ------------------------------------------------------------------------------

browserTest("dropdown-menu: Escape closes and returns focus to the trigger; a prevented close-auto-focus keeps it away", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await openWithKey(page, "Enter");
  await page.keyboard.press("Escape");
  await closedContent(page);
  await waitSlotFocus(page, "dropdown-menu-trigger");
  assert.deepEqual((await recorded(page, "open-change")).map((entry) => [entry.open, entry.slot]),
    [[true, "dropdown-menu-trigger"], [false, "dropdown-menu-trigger"]]);

  await record(page, { prevent: ["close-auto-focus"] });
  await page.keyboard.press("Enter");
  await openContent(page);
  await waitItemFocus(page, "Profile");
  await page.keyboard.press("Escape");
  await closedContent(page);
  await settle(page);
  assert.notEqual((await active(page)).slot, "dropdown-menu-trigger");
  assert.deepEqual((await recorded(page, "close-auto-focus")).map((entry) => entry.cancelable), [true]);
});

browserTest("dropdown-menu: a prevented escape-key-down keeps the menu open", async ({ open }) => {
  const page = await open("closed__default");
  await record(page, { prevent: ["escape-key-down"] });
  await openWithKey(page, "Enter");
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => window.__menu.some((entry) => entry.name === "escape-key-down"));
  await settle(page);
  assert.equal(await page.locator(content).getAttribute("data-state"), "open");
  assert.deepEqual((await recorded(page, "escape-key-down")).map((entry) => [entry.cancelable, entry.slot]), [[true, "dropdown-menu-content"]]);
});

browserTest("dropdown-menu: a prevented open-auto-focus leaves the content unfocused", async ({ open }) => {
  const page = await open("closed__default");
  await record(page, { prevent: ["open-auto-focus"] });
  await page.click(trigger);
  await openContent(page);
  await page.waitForFunction(() => window.__menu.some((entry) => entry.name === "open-auto-focus"));
  await settle(page);
  assert.equal(await page.locator(content).evaluate((menu) => menu.contains(document.activeElement)), false);
  assert.deepEqual((await recorded(page, "open-auto-focus")).map((entry) => entry.cancelable), [true]);
});

browserTest("dropdown-menu: a controlled open menu fires open-change on Escape but stays open", async ({ open }) => {
  const page = await open("open__controlled-open-stays-on-escape");
  await record(page);
  await openContent(page);
  await page.locator(content).focus();
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => window.__menu.some((entry) => entry.name === "open-change"));
  await settle(page);
  assert.deepEqual((await recorded(page, "open-change")).map((entry) => entry.open), [false]);
  assert.equal(await page.locator(content).getAttribute("data-state"), "open");
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "true");
});

// --- selection -----------------------------------------------------------------------------------------------------------

browserTest("dropdown-menu: selecting an item closes the menu and returns focus; a prevented select keeps it open", async ({ open }) => {
  const page = await open("closed__default");
  await record(page, { prevent: ["select"] });
  await openWithKey(page, "Enter");
  await waitItemFocus(page, "Profile");
  await page.keyboard.press("Enter");
  await page.waitForFunction(() => window.__menu.some((entry) => entry.name === "select"));
  await settle(page);
  assert.equal(await page.locator(content).getAttribute("data-state"), "open", "prevented select keeps the menu open");

  await record(page);
  await page.click("[role=menuitem]:text-is('Team')");
  await closedContent(page);
  await waitSlotFocus(page, "dropdown-menu-trigger");
  assert.deepEqual((await recorded(page)).filter((entry) => entry.name !== "close-auto-focus").map((entry) => [entry.name, entry.text]),
    [["select", "Team"], ["open-change", "Open"]]);
  assert.equal((await recorded(page, "select"))[0].cancelable, true);
});

browserTest("dropdown-menu: checkbox items report the next checked state and never flip themselves", async ({ open }) => {
  const page = await open("checkbox__states");
  await record(page, { prevent: ["select"] });
  await openContent(page);
  const items = page.locator("[role=menuitemcheckbox]");
  const states = () => items.evaluateAll((menuItems) => menuItems.map((menuItem) => [menuItem.textContent.trim(), menuItem.getAttribute("aria-checked"), menuItem.dataset.state]));
  const before = await states();
  assert.deepEqual(before, [["Status Bar", "true", "checked"], ["Activity Bar", "false", "unchecked"], ["Panel", "mixed", "indeterminate"], ["Minimap", "false", "unchecked"]]);
  for (const name of ["Status Bar", "Activity Bar", "Panel"]) await page.click(`[role=menuitemcheckbox]:text-is('${name}')`);
  await page.waitForFunction(() => window.__menu.filter((entry) => entry.name === "checked-change").length === 3);
  // checked-change fires even though select was prevented; indeterminate goes to true.
  assert.deepEqual((await recorded(page, "checked-change")).map((entry) => [entry.text, entry.checked, entry.cancelable]),
    [["Status Bar", false, false], ["Activity Bar", true, false], ["Panel", true, false]]);
  assert.deepEqual(await states(), before, "controlled only: the port never changes aria-checked");
  assert.equal(await page.locator(content).getAttribute("data-state"), "open");
});

browserTest("dropdown-menu: a radio item reports its value and closes the menu", async ({ open }) => {
  const page = await open("radio__value");
  await record(page);
  await openContent(page);
  assert.equal(await page.locator("[role=menuitemradio][aria-checked=true]").textContent(), "Bottom", "precondition");
  await page.click("[role=menuitemradio]:text-is('Top')");
  await closedContent(page);
  assert.deepEqual((await recorded(page, "value-change")).map((entry) => [entry.value, entry.cancelable, entry.slot]), [["top", false, "dropdown-menu-radio-item"]]);
  assert.deepEqual((await recorded(page, "select")).map((entry) => entry.text), ["Top"]);
});

// --- modality and outside interaction -------------------------------------------------------------------------------------

browserTest("dropdown-menu: modal locks the page while open; an outside press dismisses and focus returns to the trigger", async ({ open }) => {
  const page = await open("closed__default");
  const idle = await bodyState(page);
  await record(page);
  await page.click(trigger);
  await openContent(page);
  await settle(page);
  const locked = await bodyState(page);
  assert.equal(locked.pointerEvents, "none");
  assert.equal(locked.scrollLocked, true);
  assert.ok(locked.hidden > idle.hidden, "outside is aria-hidden");
  await pressOutside(page);
  await closedContent(page);
  await waitSlotFocus(page, "dropdown-menu-trigger");
  assert.deepEqual(await bodyState(page), idle);
  const names = (await recorded(page)).map((entry) => entry.name);
  assert.ok(names.indexOf("pointer-down-outside") >= 0 && names.indexOf("pointer-down-outside") < names.indexOf("interact-outside"), names.join(","));
});

browserTest("dropdown-menu: non-modal leaves the page alone and an outside press does not return focus to the trigger", async ({ open }) => {
  const page = await open("non-modal__open");
  const idle = await bodyState(page);
  await page.click(trigger);
  await openContent(page);
  await settle(page);
  assert.deepEqual(await bodyState(page), idle);
  await pressOutside(page);
  await closedContent(page);
  await settle(page);
  assert.notEqual((await active(page)).slot, "dropdown-menu-trigger");
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false");
});

for (const prevented of ["pointer-down-outside", "interact-outside"]) {
  browserTest(`dropdown-menu: a prevented ${prevented} keeps the menu open after an outside press`, async ({ open }) => {
    const page = await open("closed__default");
    await record(page, { prevent: [prevented] });
    await page.click(trigger);
    await openContent(page);
    await settle(page);
    await pressOutside(page);
    await page.waitForFunction((name) => window.__menu.some((entry) => entry.name === name), prevented);
    await settle(page);
    assert.equal(await page.locator(content).getAttribute("data-state"), "open");
    assert.deepEqual((await recorded(page, prevented)).map((entry) => [entry.cancelable, entry.slot]), [[true, "dropdown-menu-content"]]);
  });
}

browserTest("dropdown-menu: a window blur closes the open menu", async ({ open }) => {
  const page = await open("closed__default");
  await page.click(trigger);
  await openContent(page);
  await page.evaluate(() => window.dispatchEvent(new Event("blur")));
  await closedContent(page);
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false");
});

// --- disconnect and Turbo ------------------------------------------------------------------------------------------------

browserTest("dropdown-menu: removing the open host releases everything and leaves no listener; reinserting works", async ({ open }) => {
  const page = await open("closed__default");
  const idle = await bodyState(page);
  await page.click(trigger);
  await openContent(page);
  await settle(page);
  assert.equal((await bodyState(page)).scrollLocked, true, "precondition: locked");
  await page.evaluate(async (selector) => {
    const host = document.querySelector(selector);
    window.__host = { detached: host, parent: host.parentNode, next: host.nextSibling };
    host.remove();
    await new Promise((resolve) => setTimeout(resolve));
  }, trigger);
  await settle(page);
  assert.equal(await page.locator(content).count(), 0, "no portaled content left");
  assert.deepEqual(await bodyState(page), idle);
  // A listener left on window/document would still drive the detached host (it was left open).
  const leftovers = await page.evaluate(() => {
    const { detached } = window.__host;
    window.dispatchEvent(new Event("blur"));
    const afterBlur = detached.getAttribute("aria-expanded");
    document.dispatchEvent(new Event("turbo:before-cache"));
    return { afterBlur, afterBeforeCache: detached.getAttribute("aria-expanded") };
  });
  assert.deepEqual(leftovers, { afterBlur: "true", afterBeforeCache: "true" });

  await page.evaluate(async () => {
    const { detached, parent, next } = window.__host;
    parent.insertBefore(detached, next);
    await new Promise((resolve) => setTimeout(resolve));
  });
  await settle(page);
  // It reconnects in the state its open value holds (open), with exactly one content, and closes and reopens normally.
  assert.equal(await page.locator(content).count(), 1);
  await page.locator(content).focus();
  await page.keyboard.press("Escape");
  await closedContent(page);
  assert.deepEqual(await bodyState(page), idle);
  await page.focus(trigger);
  await page.keyboard.press("Enter");
  await openContent(page);
  await waitItemFocus(page, "Profile");
});

browserTest("dropdown-menu: the Turbo snapshot holds a closed menu and the restored host opens again", async ({ open }) => {
  const page = await open("closed__default");
  const idle = await bodyState(page);
  await openWithKey(page, "Enter");
  assert.equal((await bodyState(page)).pointerEvents, "none", "precondition: open and modal");
  const html = await snapshot(page, CONTROLLER);
  assert.equal(await page.locator(content).count(), 0, "nothing open at the snapshot");
  assert.deepEqual(await bodyState(page), idle);
  assert.equal(await countIn(page, html, "[aria-expanded=true], [data-state=open]"), 0);
  assert.equal(await countIn(page, html, `[data-${CONTROLLER}-open-value=true]`), 0);

  await restore(page, CONTROLLER, html);
  assert.equal(await page.locator(content).count(), 0, "the restored host connects closed");
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "false");
  await openWithKey(page, "ArrowDown");
  await waitItemFocus(page, "Profile");
  assert.equal(await page.locator(content).count(), 1);
});
