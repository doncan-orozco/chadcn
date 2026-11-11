// chadcn--navigation-menu in a real browser: the behavior contract of dev/port/specs/navigation-menu.md (Behavior) beyond what
// the parity runner compares: the toggle, the focus group, the content entry and tab order, the three dismissals, link select,
// data-motion and the viewport/indicator states, the public events (and a caller's preventDefault), pointer types, disconnect
// cleanup and the Turbo cache restore.
import { browserTest } from "./harness.mjs";
import { assert, host, settle } from "./support.mjs";
import { snapshot, restore, countIn } from "./turbo_support.mjs";

browserTest.component = "navigation-menu";
const CONTROLLER = "chadcn--navigation-menu";
const VIEWPORT = "[data-slot=navigation-menu-viewport]";
const CONTENT = "[data-slot=navigation-menu-content]";
const INDICATOR = "[data-slot=navigation-menu-indicator]";
const PROXY = "[data-slot=navigation-menu-item] > span[aria-hidden=true][tabindex='0']";
const EVENTS = ["value-change", "link-select", "escape-key-down", "pointer-down-outside", "focus-outside"];

const trigger = (page, name) => page.getByRole("button", { name, exact: true });
const link = (page, name) => page.getByRole("link", { name, exact: true });
const state = (locator) => locator.getAttribute("data-state");
const waitState = (locator, value) => locator.and(locator.page().locator(`[data-state=${value}]`)).waitFor();
const waitFocus = (locator) => locator.and(locator.page().locator(":focus")).waitFor();
const focused = (locator) => locator.evaluate((element) => element === document.activeElement);
const contentOf = async (page, name) => page.locator(`#${await trigger(page, name).getAttribute("data-chadcn--navigation-menu-controls-param")}`);
const finishAnimations = (locator) => locator.evaluate((element) => Promise.all(element.getAnimations({ subtree: true }).map((animation) => animation.finished)));

// Records the controller's public events (they bubble to document) with their detail; `prevent` calls preventDefault on some.
const record = (page, { prevent = [] } = {}) => page.evaluate(({ names, prefix, prevent }) => {
  window.__nav = [];
  for (const name of names) {
    document.addEventListener(`${prefix}:${name}`, (event) => {
      window.__nav.push({ name, cancelable: event.cancelable, slot: event.target.dataset?.slot, ...(name === "value-change" ? { value: event.detail.value } : {}) });
      if (prevent.includes(name)) event.preventDefault();
    });
  }
}, { names: EVENTS, prefix: CONTROLLER, prevent });
const recorded = (page, name) => page.evaluate((name) => window.__nav.filter((entry) => entry.name === name), name);

// A click on the trigger without a pointer move (a real mouse move starts the 200ms hover-open timer, which a second fast
// click would race); the toggle under test is the click handler, which Enter/Space reach through the native button.
const clickTrigger = (page, name) => trigger(page, name).dispatchEvent("click");

// Opens an item with the keyboard (focus never opens, Enter clicks the native button).
async function openWithKeyboard(page, name) {
  await trigger(page, name).focus();
  await page.keyboard.press("Enter");
  await waitState(trigger(page, name), "open");
}

// The harness disables every animation; the exit states (viewport data-state=closed, data-motion=to-*) are only observable
// while an exit animation keeps the part mounted, so these tests put the motion back.
const enableMotion = (page) => page.evaluate(() => {
  for (const style of document.querySelectorAll("style")) if (style.textContent.includes("animation:none!important")) style.remove();
});

// ---- click, Enter/Space ----------------------------------------------------------------------------------------------

browserTest("navigation-menu: a click toggles the item open and closed (data-state, aria-expanded, aria-controls, viewport)", async ({ open }) => {
  const page = await open("closed__default");
  const button = trigger(page, "Getting started");
  assert.equal(await state(button), "closed", "precondition: closed");
  assert.equal(await button.getAttribute("aria-controls"), null);
  assert.equal(await page.locator(VIEWPORT).count(), 0, "precondition: no viewport while closed");

  await clickTrigger(page, "Getting started");
  await waitState(button, "open");
  assert.equal(await button.getAttribute("aria-expanded"), "true");
  const content = await contentOf(page, "Getting started");
  assert.equal(await button.getAttribute("aria-controls"), await content.getAttribute("id"));
  assert.equal(await page.locator(VIEWPORT).getAttribute("data-state"), "open");
  assert.equal(await page.locator(`${VIEWPORT} ${CONTENT}`).count(), 1, "the open content is mounted inside the viewport");
  assert.equal(await content.getAttribute("data-state"), null, "viewport-mode content has no data-state");
  assert.equal(await page.locator(`${PROXY} + span[aria-owns]`).getAttribute("aria-owns"), await content.getAttribute("id"));
  assert.equal(await state(trigger(page, "Components")), "closed");

  await clickTrigger(page, "Getting started");
  await waitState(button, "closed");
  assert.equal(await button.getAttribute("aria-expanded"), "false");
  assert.equal(await button.getAttribute("aria-controls"), null);
  await page.locator(VIEWPORT).waitFor({ state: "detached" });
  assert.equal(await page.locator(CONTENT).count(), 0);
  assert.equal(await page.locator(PROXY).count(), 0);
});

browserTest("navigation-menu: value-change carries the new value on open, switch and close", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  const first = await trigger(page, "Getting started").getAttribute("data-chadcn--navigation-menu-value-param");
  const second = await trigger(page, "Components").getAttribute("data-chadcn--navigation-menu-value-param");
  await clickTrigger(page, "Getting started");
  await clickTrigger(page, "Components");
  await clickTrigger(page, "Components");
  await waitState(trigger(page, "Components"), "closed");
  assert.deepEqual((await recorded(page, "value-change")).map((entry) => entry.value), [first, second, ""]);
});

browserTest("navigation-menu: Enter and Space toggle a focused trigger; focus alone never opens", async ({ open }) => {
  const page = await open("closed__default");
  const button = trigger(page, "Getting started");
  await button.focus();
  await settle(page);
  assert.equal(await state(button), "closed", "focus does not open");

  await page.keyboard.press("Enter");
  await waitState(button, "open");
  await page.keyboard.press("Space");
  await waitState(button, "closed");
  await page.keyboard.press("Space");
  await waitState(button, "open");
  await page.keyboard.press("Enter");
  await waitState(button, "closed");
  assert.equal(await page.locator(CONTENT).count(), 0);
});

browserTest("navigation-menu: no-viewport mode mounts the content in its item with data-state and no aria-owns span", async ({ open }) => {
  const page = await open("closed__no-viewport");
  const button = trigger(page, "Getting started");
  await clickTrigger(page, "Getting started");
  await waitState(button, "open");
  const content = await contentOf(page, "Getting started");
  assert.equal(await content.getAttribute("data-state"), "open");
  assert.equal(await page.locator(VIEWPORT).count(), 0);
  assert.ok(await content.evaluate((element) => element.closest("[data-slot=navigation-menu-item]") !== null), "content lives in its item");
  assert.equal(await page.locator(PROXY).count(), 1, "the focus proxy is there");
  assert.equal(await page.locator("span[aria-owns]").count(), 0);
});

// ---- focus group -----------------------------------------------------------------------------------------------------

browserTest("navigation-menu: arrows, Home and End move focus between the top-level items without looping", async ({ open }) => {
  const page = await open("closed__default");
  await trigger(page, "Getting started").focus();
  await page.keyboard.press("ArrowRight");
  await waitFocus(trigger(page, "Components"));
  await page.keyboard.press("ArrowRight");
  await waitFocus(link(page, "Docs"));
  await page.keyboard.press("ArrowRight");
  await settle(page);
  assert.equal(await focused(link(page, "Docs")), true, "no loop at the last item");
  await page.keyboard.press("Home");
  await waitFocus(trigger(page, "Getting started"));
  await page.keyboard.press("ArrowLeft");
  await settle(page);
  assert.equal(await focused(trigger(page, "Getting started")), true, "no loop at the first item");
  await page.keyboard.press("End");
  await waitFocus(link(page, "Docs"));
  await page.keyboard.press("ArrowLeft");
  await waitFocus(trigger(page, "Components"));
  assert.equal(await state(trigger(page, "Components")), "closed", "moving focus never opens");
});

browserTest("navigation-menu: dir=rtl swaps the horizontal arrows", async ({ open }) => {
  const page = await open("closed__dir-rtl");
  await trigger(page, "Components").focus();
  await page.keyboard.press("ArrowRight");
  await waitFocus(trigger(page, "Getting started"));
  await page.keyboard.press("ArrowLeft");
  await waitFocus(trigger(page, "Components"));
});

browserTest("navigation-menu: ArrowDown on an open trigger enters the content; on a closed trigger it moves to the next item", async ({ open }) => {
  const page = await open("closed__default");
  await trigger(page, "Getting started").focus();
  await page.keyboard.press("ArrowDown");
  await waitFocus(trigger(page, "Components"));
  assert.equal(await state(trigger(page, "Components")), "closed");

  await page.keyboard.press("Enter");
  await waitState(trigger(page, "Components"), "open");
  await page.keyboard.press("ArrowDown");
  await waitFocus(link(page, "Alert Dialog"));
  // Inside the content the links are their own focus group.
  await page.keyboard.press("ArrowDown");
  await waitFocus(link(page, "Hover Card"));
  await page.keyboard.press("End");
  await waitFocus(link(page, "Tooltip"));
  assert.equal(await state(trigger(page, "Components")), "open");
});

browserTest("navigation-menu: orientation=vertical enters the content with ArrowRight", async ({ open }) => {
  const page = await open("closed__orientation-vertical");
  await openWithKeyboard(page, "Getting started");
  await page.keyboard.press("ArrowRight");
  await waitFocus(link(page, "Introduction"));
});

// ---- tab order -------------------------------------------------------------------------------------------------------

browserTest("navigation-menu: Tab goes from the open trigger into the content, through it and out to the next trigger", async ({ open }) => {
  const page = await open("closed__default");
  await openWithKeyboard(page, "Getting started");
  await page.keyboard.press("Tab");
  await waitFocus(link(page, "Introduction"));
  await page.keyboard.press("Tab");
  await waitFocus(link(page, "Installation"));
  await page.keyboard.press("Tab");
  await waitFocus(link(page, "Typography"));
  await page.keyboard.press("Tab");
  await waitFocus(trigger(page, "Components"));
  // Focus moved inside the nav: the menu stays open, the content links left the tab order.
  assert.equal(await state(trigger(page, "Getting started")), "open");
  const tabindexes = await page.locator(`${CONTENT} [data-slot=navigation-menu-link]`).evaluateAll((contentLinks) => contentLinks.map((contentLink) => [contentLink.getAttribute("tabindex"), contentLink.dataset.tabindex]));
  assert.deepEqual(tabindexes, [["-1", ""], ["-1", ""], ["-1", ""]]);

  await page.keyboard.press("Shift+Tab");
  await waitFocus(link(page, "Typography"));
  assert.equal(await link(page, "Typography").getAttribute("tabindex"), "", "entry restores the saved tabindex");
});

browserTest("navigation-menu: Shift+Tab from the next trigger enters the content at its end", async ({ open }) => {
  const page = await open("closed__default");
  await openWithKeyboard(page, "Getting started");
  await trigger(page, "Components").focus();
  await page.keyboard.press("Shift+Tab");
  await waitFocus(link(page, "Typography"));
});

// ---- dismissal -------------------------------------------------------------------------------------------------------

browserTest("navigation-menu: Escape in the content closes it, focuses the trigger and dispatches escape-key-down", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await openWithKeyboard(page, "Getting started");
  await page.keyboard.press("ArrowDown");
  await waitFocus(link(page, "Introduction"));
  await page.keyboard.press("Escape");
  await waitState(trigger(page, "Getting started"), "closed");
  await waitFocus(trigger(page, "Getting started"));
  assert.deepEqual(await recorded(page, "escape-key-down"), [{ name: "escape-key-down", cancelable: true, slot: "navigation-menu-content" }]);
});

browserTest("navigation-menu: a caller's preventDefault on escape-key-down keeps the menu open", async ({ open }) => {
  const page = await open("closed__default");
  await record(page, { prevent: ["escape-key-down"] });
  await openWithKeyboard(page, "Getting started");
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => window.__nav.some((entry) => entry.name === "escape-key-down"));
  await settle(page);
  assert.equal(await state(trigger(page, "Getting started")), "open");
});

browserTest("navigation-menu: focus leaving the nav from inside dismisses; focus moving inside the nav does not", async ({ open }) => {
  const page = await open("closed__default");
  await openWithKeyboard(page, "Components");
  await link(page, "Docs").focus();
  await settle(page);
  assert.equal(await state(trigger(page, "Components")), "open", "control: focus inside the nav keeps it open");

  await page.keyboard.press("Tab");
  await waitFocus(page.getByRole("button", { name: "After" }));
  await waitState(trigger(page, "Components"), "closed");
});

browserTest("navigation-menu: pointerdown outside closes, pointerdown on the viewport (outside the content) keeps it open", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await clickTrigger(page, "Getting started");
  await waitState(trigger(page, "Getting started"), "open");
  await settle(page); // the layer's outside listener is armed one timer tick after mount

  // The viewport element itself is outside the content layer: pointer-down-outside fires and the menu prevents it.
  await page.locator(VIEWPORT).dispatchEvent("pointerdown", { pointerType: "mouse", button: 0, isPrimary: true });
  await settle(page);
  assert.equal(await state(trigger(page, "Getting started")), "open", "control: the viewport press");

  await page.getByTestId("outside").click();
  await waitState(trigger(page, "Getting started"), "closed");
  const outside = await recorded(page, "pointer-down-outside");
  assert.equal(outside.length, 2, "dispatched for both presses");
  assert.ok(outside.every((entry) => entry.cancelable));
});

browserTest("navigation-menu: pointerdown on a top-level link closes, pointerdown on another trigger switches", async ({ open }) => {
  const page = await open("closed__default");
  await clickTrigger(page, "Getting started");
  await waitState(trigger(page, "Getting started"), "open");
  await settle(page);
  await trigger(page, "Components").dispatchEvent("pointerdown", { pointerType: "mouse", button: 0, isPrimary: true });
  await settle(page);
  assert.equal(await state(trigger(page, "Getting started")), "open", "control: a trigger press is not outside");
  await link(page, "Docs").dispatchEvent("pointerdown", { pointerType: "mouse", button: 0, isPrimary: true });
  await waitState(trigger(page, "Getting started"), "closed");
});

// The links are #hash links: following one is a Turbo visit (turbo:before-cache), which would close the menu by itself. The
// caller's click handler prevents the navigation; Radix runs link select regardless (checkForDefaultPrevented: false).
const preventNavigation = (page) => page.evaluate(() => document.addEventListener("click", (event) => event.target.closest("a") && event.preventDefault()));

browserTest("navigation-menu: selecting a content link dispatches link-select, closes and focuses the trigger", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await preventNavigation(page);
  await openWithKeyboard(page, "Getting started");
  await page.keyboard.press("ArrowDown");
  await waitFocus(link(page, "Introduction"));
  await page.keyboard.press("Enter");
  await waitState(trigger(page, "Getting started"), "closed");
  await waitFocus(trigger(page, "Getting started"));
  assert.deepEqual(await recorded(page, "link-select"), [{ name: "link-select", cancelable: true, slot: "navigation-menu-link" }]);
});

browserTest("navigation-menu: a caller's preventDefault on link-select keeps the menu open", async ({ open }) => {
  const page = await open("closed__default");
  await record(page, { prevent: ["link-select"] });
  await preventNavigation(page);
  await openWithKeyboard(page, "Getting started");
  await page.keyboard.press("ArrowDown");
  await waitFocus(link(page, "Introduction"));
  await page.keyboard.press("Enter");
  await page.waitForFunction(() => window.__nav.some((entry) => entry.name === "link-select"));
  await settle(page);
  assert.equal(await state(trigger(page, "Getting started")), "open");
});

browserTest("navigation-menu: a meta click on a content link keeps the menu open", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await preventNavigation(page);
  await openWithKeyboard(page, "Getting started");
  await link(page, "Installation").dispatchEvent("click", { metaKey: true });
  await settle(page);
  assert.equal((await recorded(page, "link-select")).length, 1, "link-select still fires");
  assert.equal(await state(trigger(page, "Getting started")), "open");
});

// ---- motion, viewport and indicator states ---------------------------------------------------------------------------

browserTest("navigation-menu: switching items sets data-motion from-end/to-start forward and from-start/to-end back", async ({ open }) => {
  const page = await open("closed__default");
  await enableMotion(page);
  await clickTrigger(page, "Getting started");
  await waitState(trigger(page, "Getting started"), "open");
  assert.equal(await (await contentOf(page, "Getting started")).getAttribute("data-motion"), null, "opening from closed has no motion");
  await finishAnimations(page.locator(VIEWPORT));

  // Read in the task of the click: the outgoing content only stays mounted while its exit animation runs.
  const switchTo = (name) => page.evaluate((name) => {
    [...document.querySelectorAll("[data-slot=navigation-menu-trigger]")].find((navTrigger) => navTrigger.textContent.trim() === name).click();
    return [...document.querySelectorAll("[data-slot=navigation-menu-viewport] [data-slot=navigation-menu-content]")]
      .map((element) => [document.getElementById(element.getAttribute("aria-labelledby")).textContent.trim(), element.getAttribute("data-motion")]);
  }, name);
  assert.deepEqual(await switchTo("Components"), [["Getting started", "to-start"], ["Components", "from-end"]]);
  await page.locator(`${CONTENT}[data-motion=to-start]`).waitFor({ state: "detached" });
  await finishAnimations(page.locator(VIEWPORT));
  assert.deepEqual(await switchTo("Getting started"), [["Getting started", "from-start"], ["Components", "to-end"]]);
});

browserTest("navigation-menu: closing keeps the viewport with data-state=closed and no pointer events until its exit ends", async ({ open }) => {
  const page = await open("closed__default");
  await enableMotion(page);
  await clickTrigger(page, "Getting started");
  await waitState(page.locator(VIEWPORT), "open");
  assert.equal(await page.locator(VIEWPORT).evaluate((element) => element.style.pointerEvents), "", "control: open viewport takes pointers");
  await finishAnimations(page.locator(VIEWPORT));
  const closing = await page.evaluate(() => {
    document.querySelector("[data-slot=navigation-menu-trigger]").click();
    const viewport = document.querySelector("[data-slot=navigation-menu-viewport]");
    return viewport && { state: viewport.getAttribute("data-state"), pointerEvents: viewport.style.pointerEvents };
  });
  assert.deepEqual(closing, { state: "closed", pointerEvents: "none" });
  await page.locator(VIEWPORT).waitFor({ state: "detached" });
});

browserTest("navigation-menu: the viewport size variables follow the active content", async ({ open }) => {
  const page = await open("closed__default");
  await clickTrigger(page, "Getting started");
  await page.waitForFunction((selector) => document.querySelector(selector)?.style.getPropertyValue("--radix-navigation-menu-viewport-width"), VIEWPORT);
  const contentSize = await (await contentOf(page, "Getting started")).evaluate((element) => [`${element.offsetWidth}px`, `${element.offsetHeight}px`]);
  const viewportSize = await page.locator(VIEWPORT).evaluate((element) => [element.style.getPropertyValue("--radix-navigation-menu-viewport-width"), element.style.getPropertyValue("--radix-navigation-menu-viewport-height")]);
  assert.deepEqual(viewportSize, contentSize);
});

browserTest("navigation-menu: a force-mounted indicator is visible over the open trigger and hidden after close", async ({ open }) => {
  const page = await open("indicator__force-mount-hidden");
  const indicator = page.locator(INDICATOR);
  assert.equal(await indicator.count(), 0, "precondition: nothing to measure before the first open");
  await clickTrigger(page, "Getting started");
  await waitState(indicator, "visible");
  assert.equal(await indicator.getAttribute("aria-hidden"), "true");
  const width = await trigger(page, "Getting started").evaluate((element) => `${element.offsetWidth}px`);
  assert.equal(await indicator.evaluate((element) => element.style.width), width);

  await clickTrigger(page, "Getting started");
  await waitState(indicator, "hidden");
  assert.equal(await indicator.count(), 1, "force_mount keeps it mounted");
});

// ---- pointer type ----------------------------------------------------------------------------------------------------

for (const pointerType of ["touch", "pen", "mouse"]) {
  const opens = pointerType === "mouse";
  browserTest(`navigation-menu: a ${pointerType} pointermove on a trigger ${opens ? "opens it (hover)" : "does not open it"}`, async ({ open }) => {
    const page = await open("closed__default");
    // Delay 0: the mouse twin opens without a hover timer to wait out.
    await page.evaluate((selector) => document.querySelector(selector).setAttribute("data-chadcn--navigation-menu-delay-duration-value", "0"), host(CONTROLLER));
    const button = trigger(page, "Getting started");
    await button.dispatchEvent("pointerenter", { pointerType });
    await button.dispatchEvent("pointermove", { pointerType });
    if (opens) return waitState(button, "open");
    await settle(page);
    await settle(page);
    assert.equal(await state(button), "closed");
  });
}

// ---- disconnect and Turbo cache --------------------------------------------------------------------------------------

browserTest("navigation-menu: removing the host while open leaves nothing behind and a reconnected menu opens again", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await openWithKeyboard(page, "Getting started");
  await page.keyboard.press("ArrowDown");
  await waitFocus(link(page, "Introduction"));
  const leftovers = await page.evaluate(async (selector) => {
    const nav = document.querySelector(selector);
    const parent = nav.parentNode;
    const next = nav.nextSibling;
    nav.remove();
    await new Promise((resolve) => setTimeout(resolve)); // Stimulus disconnects on the mutation observer microtask
    const mounted = nav.querySelectorAll("[data-slot=navigation-menu-content], [data-slot=navigation-menu-viewport], span[aria-owns], span[aria-hidden=true][tabindex='0']").length;
    // The layer's document listeners are gone: neither of these reaches the controller.
    window.__nav.length = 0;
    document.body.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    document.body.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true }));
    const events = window.__nav.length;
    parent.insertBefore(nav, next);
    await new Promise((resolve) => setTimeout(resolve));
    return { mounted, events };
  }, host(CONTROLLER));
  assert.deepEqual(leftovers, { mounted: 0, events: 0 });
  await settle(page);
  assert.equal(await state(trigger(page, "Getting started")), "closed", "reconnects closed");
  assert.equal(await trigger(page, "Getting started").getAttribute("aria-expanded"), "false");
  await clickTrigger(page, "Getting started");
  await waitState(trigger(page, "Getting started"), "open");
  assert.equal(await page.locator(`${VIEWPORT} ${CONTENT}`).count(), 1);
});

browserTest("navigation-menu: the Turbo snapshot holds no open item and the restored menu opens again", async ({ open }) => {
  const page = await open("closed__default");
  await openWithKeyboard(page, "Components");
  assert.equal(await page.locator(CONTENT).count(), 1, "precondition: open");
  const html = await snapshot(page, CONTROLLER);
  assert.equal(await countIn(page, html, `${CONTENT}, ${VIEWPORT}, ${INDICATOR}, span[aria-owns], span[aria-hidden=true][tabindex='0']`), 0);
  assert.equal(await countIn(page, html, "[data-state=open], [aria-expanded=true], [aria-controls]"), 0);

  await restore(page, CONTROLLER, html);
  assert.equal(await page.locator(CONTENT).count(), 0);
  assert.equal(await state(trigger(page, "Components")), "closed");
  await clickTrigger(page, "Components");
  await waitState(trigger(page, "Components"), "open");
  assert.equal(await page.locator(`${VIEWPORT} ${CONTENT}`).count(), 1);
});
