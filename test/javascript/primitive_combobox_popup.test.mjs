import { assert, primitiveTest } from "./primitives_support.mjs";

// primitives/combobox_popup.js: the mounted popup of the Combobox (portal, backdrop, state attributes, empty state and live
// region, dismiss buttons, focus guards, open layers, the filtered list) and the state attributes of the controls, on a hand-written
// copy of the markup the Phlex part renders.

const P = (name) => `data-chadcn--combobox-part="${name}"`;
const item = (key, label, extra = "") => `<div ${P("item")} data-chadcn--combobox-key="${key}" data-slot="combobox-item" ${extra}>${label}</div>`;
const html = `
  <div id="host">
    <input ${P("input")} id="fruit">
    <button ${P("trigger")}>Open</button>
    <template ${P("content-template")}>
      <div ${P("positioner")}>
        <div ${P("popup")} id="fruit-popup">
          <div ${P("empty")}>No items found.</div>
          <div ${P("list")} id="fruit-list">
            <template ${P("indicator-template")}><span data-slot="combobox-item-indicator">✓</span></template>
            ${item("apple", "Apple")}
            <div ${P("group")}><div>Berries</div>${item("blueberry", "Blueberry")}${item("cherry", "Cherry", "data-disabled")}</div>
            ${item("banana", "Banana")}
          </div>
        </div>
      </div>
    </template>
  </div>
  <main id="page">page</main>`;

const mount = (page, options = {}) => page.evaluate(async (options) => {
  const { ComboboxPopup } = await import("chadcn/primitives/combobox_popup");
  const template = document.querySelector("[data-chadcn--combobox-part=content-template]");
  window.popup = new ComboboxPopup(template, { empty: false, modal: false, inPopup: false, ...options, cutout: document.querySelector("#fruit") });
}, options);

const texts = (page) => page.evaluate(() => window.popup.shown.map((el) => el.textContent));

primitiveTest("combobox_popup: mounting puts the template in a body portal, marked open with its first side and align", async (page) => {
  await mount(page, { side: "top" });
  const result = await page.evaluate(() => {
    const { popup, positioner, container, list, records } = window.popup;
    return {
      portal: container.parentElement === document.body && container.hasAttribute("data-base-ui-portal") && container.contains(positioner),
      open: [positioner, popup].map((el) => [el.hasAttribute("data-open"), el.getAttribute("data-side"), el.getAttribute("data-align")]),
      startingStyle: popup.hasAttribute("data-starting-style"),
      focusable: popup.hasAttribute("data-base-ui-focusable"),
      empty: list.hasAttribute("data-empty"),
      emptyText: document.querySelector("[data-chadcn--combobox-part=empty]").textContent,
      records: [...records.values()].map(({ key, disabled, group }) => [key, disabled, Boolean(group)]),
      backdrop: Boolean(window.popup.backdrop),
    };
  });
  assert.deepEqual(result, {
    portal: true,
    open: [[true, "top", "start"], [true, "top", "start"]],
    startingStyle: true,
    focusable: true,
    empty: false,
    emptyText: "",
    records: [["apple", false, false], ["blueberry", false, true], ["cherry", true, true], ["banana", false, false]],
    backdrop: false,
  });
}, { html });

primitiveTest("combobox_popup: the list keeps the visible items, best score first, drops empty groups and numbers the ids", async (page) => {
  await mount(page);
  await page.evaluate(() => window.popup.renderList(new Set(["banana", "apple"]), new Map([["apple", 1], ["banana", 5]]), "fruit"));
  const ranked = await texts(page);
  const ids = await page.evaluate(() => window.popup.shown.map((el) => el.id));
  const groupGone = await page.evaluate(() => document.querySelector("[data-chadcn--combobox-part=group]") === null);
  await page.evaluate(() => window.popup.renderList(new Set(["cherry"]), null, "fruit"));
  const grouped = await texts(page);
  const groupBack = await page.evaluate(() => document.querySelector("[data-chadcn--combobox-part=group]")?.firstElementChild.textContent);
  await page.evaluate(() => window.popup.renderList(null, null, "fruit"));
  assert.deepEqual(ranked, ["Banana", "Apple"], "the fuzzy score orders the items");
  assert.deepEqual(ids, ["fruit-0", "fruit-1"]);
  assert.equal(groupGone, true, "a group without a visible item leaves");
  assert.deepEqual(grouped, ["Cherry"]);
  assert.equal(groupBack, "Berries", "the group comes back with its label");
  assert.deepEqual(await texts(page), ["Apple", "Blueberry", "Cherry", "Banana"], "null shows every item in source order");
}, { html });

primitiveTest("combobox_popup: empty state, item states, indicators and the painted highlight", async (page) => {
  await mount(page);
  const result = await page.evaluate(() => {
    const popup = window.popup;
    popup.syncEmpty(true);
    const empty = [popup.positioner.hasAttribute("data-empty"), popup.empty.textContent];
    popup.syncEmpty(false);
    const filled = [popup.positioner.hasAttribute("data-empty"), popup.empty.textContent];
    popup.renderItemStates(["banana"]);
    const states = popup.shown.map((el) => [el.getAttribute("aria-selected"), el.hasAttribute("data-selected"), Boolean(el.querySelector("[data-slot=combobox-item-indicator]"))]);
    popup.renderItemStates([]);
    const cleared = popup.shown.filter((el) => el.querySelector("[data-slot=combobox-item-indicator]")).length;
    popup.renderList(null, null, "fruit");
    const input = document.querySelector("#fruit");
    popup.paintActive(1, [input]);
    const painted = [popup.shown.map((el) => el.hasAttribute("data-highlighted")), input.getAttribute("aria-activedescendant")];
    popup.paintActive(-1, [input]);
    return { empty, filled, states, cleared, painted, unpainted: input.hasAttribute("aria-activedescendant") };
  });
  assert.deepEqual(result, {
    empty: [true, "No items found."],
    filled: [false, ""],
    states: [["false", false, false], ["false", false, false], ["false", false, false], ["true", true, true]],
    cleared: 0,
    painted: [[false, true, false, false], "fruit-1"],
    unpainted: false,
  });
}, { html });

primitiveTest("combobox_popup: the live region marks the Empty text for a moment, only when the list starts empty", async (page) => {
  await mount(page, { empty: true });
  const result = await page.evaluate(async () => {
    const popup = window.popup;
    popup.announce(false);
    const notEmpty = popup.empty.textContent;
    popup.announce(true);
    const marked = popup.empty.textContent;
    popup.teardown();
    return { notEmpty, marked, restored: popup.empty.textContent };
  });
  assert.deepEqual(result, { notEmpty: "No items found.", marked: "No items found.⁠", restored: "No items found." });
}, { html });

primitiveTest("combobox_popup: a modal popup adds a backdrop, inert and aria-hidden on the page, the scroll lock; closing lifts them", async (page) => {
  await mount(page, { modal: true });
  const result = await page.evaluate(async () => {
    const { presence } = await import("chadcn/primitives/presence");
    const popup = window.popup;
    popup.presence = presence(popup.popup, {});
    const dismissed = [];
    popup.openLayers({ branches: () => [], keep: [document.querySelector("#fruit")], ariaHidden: true, onDismiss: (reason) => dismissed.push(reason) });
    const page = document.querySelector("#page");
    const open = {
      backdrop: popup.backdrop.parentElement === popup.container && popup.backdrop.style.clipPath.startsWith("polygon"),
      inert: page.hasAttribute("data-base-ui-inert"),
      hidden: page.getAttribute("aria-hidden"),
      locked: document.body.hasAttribute("data-scroll-locked") || getComputedStyle(document.body).overflow === "hidden",
    };
    popup.markClosed(false);
    const closed = {
      attributes: [popup.popup.hasAttribute("data-closed"), popup.popup.hasAttribute("data-ending-style"), popup.positioner.style.pointerEvents],
      inert: page.hasAttribute("data-base-ui-inert"),
      hidden: page.hasAttribute("aria-hidden"),
      locked: document.body.hasAttribute("data-scroll-locked"),
    };
    popup.markOpen();
    const reopened = [popup.popup.hasAttribute("data-open"), popup.popup.hasAttribute("data-closed"), popup.positioner.style.pointerEvents];
    popup.teardown();
    return { open, closed, reopened, gone: !document.querySelector("[data-base-ui-portal]"), dismissed };
  });
  assert.deepEqual(result, {
    open: { backdrop: true, inert: true, hidden: "true", locked: true },
    closed: { attributes: [true, true, "none"], inert: false, hidden: false, locked: false },
    reopened: [true, false, ""],
    gone: true,
    dismissed: [],
  });
}, { html });

primitiveTest("combobox_popup: Escape dismisses with its reason; dismiss buttons and focus guards call back and leave on teardown", async (page) => {
  await mount(page, { inPopup: true });
  const result = await page.evaluate(async () => {
    const popup = window.popup;
    const calls = [];
    popup.openLayers({ branches: () => [], keep: [], ariaHidden: false, onDismiss: (reason) => calls.push(reason) });
    await new Promise((resolve) => setTimeout(resolve, 0));
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    popup.addDismissEnd("Dismiss", () => calls.push("dismiss-end"));
    const searchPopupHasNoEnd = !popup.positioner.querySelector("[data-chadcn--combobox-part=dismiss-end]");
    const trigger = document.querySelector("[data-chadcn--combobox-part=trigger]");
    popup.addFocusGuards(trigger, () => calls.push("leave"));
    const guards = { outside: trigger.parentElement.querySelectorAll(":scope > [data-base-ui-focus-guard]").length, inside: popup.positioner.querySelectorAll("[data-base-ui-focus-guard][data-type=inside]").length };
    popup.positioner.querySelector("[data-type=inside]").focus();
    popup.teardown();
    return { calls, searchPopupHasNoEnd, guards, outsideAfter: trigger.parentElement.querySelectorAll(":scope > [data-base-ui-focus-guard]").length };
  });
  assert.deepEqual(result, { calls: ["escape-key", "leave"], searchPopupHasNoEnd: true, guards: { outside: 2, inside: 2 }, outsideAfter: 0 });
}, { html });

primitiveTest("combobox_popup: the dismiss-end button of an input popup closes it; markControls and syncDismissStart follow the state", async (page) => {
  await mount(page);
  const result = await page.evaluate(async () => {
    const { markControls, syncDismissStart } = await import("chadcn/primitives/combobox_popup");
    const popup = window.popup;
    const calls = [];
    popup.addDismissEnd("Dismiss", () => calls.push("close-press"));
    const end = popup.positioner.querySelector("[data-chadcn--combobox-part=dismiss-end]");
    end.click();
    const host = document.querySelector("#host");
    const input = document.querySelector("#fruit");
    const trigger = document.querySelector("[data-chadcn--combobox-part=trigger]");
    const attrs = (el) => ["aria-expanded", "aria-controls", "data-popup-open", "data-list-empty", "data-popup-side", "data-placeholder"].map((name) => el.getAttribute(name));
    markControls({ control: input, trigger, popup, open: true, empty: true, placeholder: true, inPopup: false, id: "fruit" });
    const open = [attrs(input), attrs(trigger)];
    syncDismissStart(host, input, true, "Dismiss");
    syncDismissStart(host, input, true, "Dismiss");
    const starts = host.querySelectorAll("[data-chadcn--combobox-part=dismiss-start]").length;
    const before = input.previousElementSibling.getAttribute("aria-label");
    markControls({ control: input, trigger, popup: null, open: false, empty: false, placeholder: false, inPopup: false, id: "fruit" });
    syncDismissStart(host, input, false, "Dismiss");
    popup.teardown();
    return { calls, role: end.getAttribute("role"), open, closed: [attrs(input), attrs(trigger)], starts, before, startsAfter: host.querySelectorAll("[data-chadcn--combobox-part=dismiss-start]").length };
  });
  assert.deepEqual(result, {
    calls: ["close-press"],
    role: "button",
    open: [["true", "fruit-list", "", "", "bottom", null], ["true", "fruit-list", "", "", "bottom", ""]],
    closed: [["false", null, null, null, null, null], ["false", null, null, null, null, null]],
    starts: 1,
    before: "Dismiss",
    startsAfter: 0,
  });
}, { html });
