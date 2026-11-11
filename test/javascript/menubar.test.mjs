import { browserTest } from "./harness.mjs";
import { assert, host, reconnect, settle } from "./support.mjs";
import { countIn, restore, snapshot } from "./turbo_support.mjs";

// chadcn--menubar (spec dev/port/specs/menubar.md): the menubar-specific behavior (trigger roving, opening, switching menus,
// focus return, outside dismissal), the public events and their cancelable variants, checkbox/radio items, disconnect and the
// Turbo cache. The Content/item mechanics shared with dropdown-menu are covered by the parity scenarios.
browserTest.component = "menubar";
const CONTROLLER = "chadcn--menubar";
const root = "[data-slot=menubar]";
const content = "[data-slot=menubar-content]";
const subContent = "[data-slot=menubar-sub-content]";
const subTrigger = "[data-slot=menubar-sub-trigger]";
const outside = "[data-testid=outside]";

const trigger = (page, name) => page.locator(root).getByRole("menuitem", { name, exact: true });
const openTrigger = (page, name) => page.locator("[data-slot=menubar-trigger][data-state=open]", { hasText: name });
const openContent = (page) => page.locator(`${content}[data-state=open]`);
const triggerStates = (page) => page.locator("[data-slot=menubar-trigger]").evaluateAll((els) => els.map((el) => `${el.textContent.trim()}:${el.dataset.state}`));

// The focused element as "<data-slot>:<text>" for triggers and items, else its data-slot (or tag name).
const describeFocus = () => {
  const el = document.activeElement;
  const slot = el?.getAttribute("data-slot") ?? el?.tagName;
  return /trigger|item/.test(slot) ? `${slot}:${el.textContent.trim()}` : slot;
};
const focused = (page) => page.evaluate(describeFocus);
const waitFocus = (page, expected) => page.waitForFunction(`(${describeFocus})() === ${JSON.stringify(expected)}`, null, { timeout: 3000 })
  .catch(async () => assert.fail(`focus on ${await focused(page)}, expected ${expected}`));

// Every public event of the controller, with its target slot and the serializable part of its detail.
const NAMES = ["value-change", "open-change", "select", "checked-change", "escape-key-down", "pointer-down-outside", "focus-outside", "interact-outside", "open-auto-focus", "close-auto-focus"];
const record = (page, { prevent = [] } = {}) => page.evaluate(({ names, prevent }) => {
  window.__log = [];
  for (const name of names) {
    document.addEventListener(`chadcn--menubar:${name}`, (event) => {
      const { value, open, checked } = event.detail ?? {};
      window.__log.push({ name, slot: event.target.getAttribute?.("data-slot"), value, open, checked, cancelable: event.cancelable });
      if (prevent.includes(name)) event.preventDefault();
    });
  }
}, { names: NAMES, prevent });
const log = (page, name) => page.evaluate((name) => window.__log.filter((e) => !name || e.name === name), name);
const waitLog = (page, name, count = 1) => page.waitForFunction(({ name, count }) => window.__log.filter((e) => e.name === name).length >= count, { name, count }, { timeout: 3000 });

// Keyboard open of a trigger: focus it and press a key.
const keyOpen = async (page, name, key = "Enter") => {
  await trigger(page, name).focus();
  await page.keyboard.press(key);
  await openContent(page).waitFor();
  await settle(page);
};
const clickOpen = async (page, name) => {
  await trigger(page, name).click();
  await openContent(page).waitFor();
  await settle(page);
};

// --- trigger roving ---------------------------------------------------------------------------------------------------

browserTest("menubar: entering the bar focuses the first trigger; ArrowRight/ArrowLeft/Home/End rove, loop and skip a disabled trigger, nothing opens", async ({ open }) => {
  const page = await open("nav__skips-disabled-trigger");
  await record(page);
  await page.locator(root).focus();
  await waitFocus(page, "menubar-trigger:File");
  assert.equal(await trigger(page, "File").getAttribute("data-highlighted"), "", "the focused trigger is highlighted");
  await page.keyboard.press("ArrowRight");
  await waitFocus(page, "menubar-trigger:View"); // Edit is disabled
  assert.equal(await trigger(page, "View").getAttribute("tabindex"), "0", "the focused trigger is the tab stop");
  assert.equal(await trigger(page, "File").getAttribute("tabindex"), "-1");
  assert.equal(await trigger(page, "File").getAttribute("data-highlighted"), null);
  await page.keyboard.press("ArrowRight");
  await waitFocus(page, "menubar-trigger:File"); // loop
  await page.keyboard.press("ArrowLeft");
  await waitFocus(page, "menubar-trigger:View"); // loop backwards, skipping Edit
  await page.keyboard.press("Home");
  await waitFocus(page, "menubar-trigger:File");
  await page.keyboard.press("End");
  await waitFocus(page, "menubar-trigger:View");
  await settle(page);
  assert.deepEqual(await triggerStates(page), ["File:closed", "Edit:closed", "View:closed"]);
  assert.equal(await page.locator(content).count(), 0);
  assert.deepEqual(await log(page, "value-change"), []);
});

browserTest("menubar: loop false stops the trigger roving at the last trigger", async ({ open }) => {
  const page = await open("focus__loop-false");
  await trigger(page, "View").focus();
  await page.keyboard.press("ArrowLeft");
  await waitFocus(page, "menubar-trigger:Edit"); // control: the roving works
  await page.keyboard.press("ArrowRight");
  await waitFocus(page, "menubar-trigger:View");
  await page.keyboard.press("ArrowRight");
  await settle(page);
  assert.equal(await focused(page), "menubar-trigger:View");
});

// --- opening ---------------------------------------------------------------------------------------------------------

for (const key of ["Enter", "Space", "ArrowDown"]) {
  browserTest(`menubar: ${key} on a trigger opens its menu, dispatches value-change and focuses the first item`, async ({ open }) => {
    const page = await open("closed__default");
    await record(page);
    const file = trigger(page, "File");
    assert.equal(await file.getAttribute("aria-expanded"), "false", "precondition: closed");
    await keyOpen(page, "File", key === "Space" ? " " : key);
    assert.equal(await file.getAttribute("aria-expanded"), "true");
    assert.equal(await file.getAttribute("data-state"), "open");
    assert.equal(await file.getAttribute("aria-controls"), await openContent(page).getAttribute("id"));
    assert.equal(await openContent(page).getAttribute("aria-labelledby"), await file.getAttribute("id"));
    await waitFocus(page, "menubar-item:New Tab⌘T");
    const changes = await log(page, "value-change");
    assert.deepEqual(changes.map((e) => [e.slot, e.value]), [["menubar", await file.getAttribute("data-chadcn--menubar-menu-value")]]);
  });
}

browserTest("menubar: a click opens the menu with the content focused and no item highlighted; a second click closes it", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await clickOpen(page, "File");
  await waitFocus(page, "menubar-content");
  assert.equal(await page.locator(`${content} [data-highlighted]`).count(), 0);
  await trigger(page, "File").click();
  await page.locator(content).waitFor({ state: "detached" });
  assert.equal(await trigger(page, "File").getAttribute("aria-expanded"), "false");
  assert.equal(await focused(page), "menubar-trigger:File");
  assert.deepEqual((await log(page, "value-change")).map((e) => e.value === ""), [false, true]);
});

browserTest("menubar: a caller preventDefault on open-auto-focus keeps the focus off the content", async ({ open }) => {
  const page = await open("closed__default");
  await record(page, { prevent: ["open-auto-focus"] });
  await clickOpen(page, "File");
  assert.deepEqual((await log(page, "open-auto-focus")).map((e) => [e.slot, e.cancelable]), [["menubar-content", true]]);
  assert.notEqual(await focused(page), "menubar-content");
});

// --- switching menus -------------------------------------------------------------------------------------------------

browserTest("menubar: ArrowRight/ArrowLeft in an open content switch to the next/previous menu, with loop", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await keyOpen(page, "File");
  await page.keyboard.press("ArrowRight");
  await openTrigger(page, "Edit").waitFor();
  assert.deepEqual(await triggerStates(page), ["File:closed", "Edit:open", "View:closed"]);
  assert.equal(await openContent(page).count(), 1);
  assert.match(await openContent(page).textContent(), /Undo/);
  await waitFocus(page, "menubar-content"); // a switch is not a keyboard trigger open: no item focused
  await page.keyboard.press("ArrowLeft");
  await openTrigger(page, "File").waitFor();
  await page.keyboard.press("ArrowLeft");
  await openTrigger(page, "View").waitFor(); // loop to the last
  assert.deepEqual(await triggerStates(page), ["File:closed", "Edit:closed", "View:open"]);
  assert.equal(await trigger(page, "View").getAttribute("tabindex"), "0", "the opened menu's trigger is the tab stop");
  const values = (await log(page, "value-change")).map((e) => e.value);
  assert.equal(values.length, 4);
  assert.ok(values.every(Boolean), values.join(","));
});

browserTest("menubar: switching menus with ArrowRight/ArrowLeft skips a disabled trigger", async ({ open }) => {
  const page = await open("nav__skips-disabled-trigger");
  await keyOpen(page, "File");
  await page.keyboard.press("ArrowRight");
  await openTrigger(page, "View").waitFor();
  assert.deepEqual(await triggerStates(page), ["File:closed", "Edit:closed", "View:open"]);
  await page.keyboard.press("ArrowLeft");
  await openTrigger(page, "File").waitFor();
  assert.deepEqual(await triggerStates(page), ["File:open", "Edit:closed", "View:closed"]);
});

browserTest("menubar: ArrowRight on a sub trigger opens the sub (open-change); ArrowRight inside the sub switches to the next menu", async ({ open }) => {
  const page = await open("nav__arrowright-inside-sub-next-menu");
  await record(page);
  await keyOpen(page, "File");
  await page.locator(subTrigger).focus();
  await page.keyboard.press("ArrowRight");
  await page.locator(`${subContent}[data-state=open]`).waitFor();
  await waitFocus(page, "menubar-item:Email link");
  assert.equal(await page.locator(subTrigger).getAttribute("aria-expanded"), "true");
  assert.deepEqual((await log(page, "open-change")).map((e) => [e.slot, e.open]), [["menubar-sub-trigger", true]]);
  assert.equal(await trigger(page, "File").getAttribute("data-state"), "open", "the sub trigger did not switch menus");
  await page.keyboard.press("ArrowRight");
  await openTrigger(page, "Edit").waitFor();
  assert.equal(await trigger(page, "File").getAttribute("data-state"), "closed");
  await page.locator(subContent).waitFor({ state: "detached" });
  assert.deepEqual((await log(page, "value-change")).map((e) => e.value), ["file", "edit"]);
});

browserTest("menubar: ArrowLeft inside a sub closes the sub, focuses its trigger and keeps the menu open", async ({ open }) => {
  const page = await open("nav__arrowright-inside-sub-next-menu");
  await record(page);
  await keyOpen(page, "File");
  await page.locator(subTrigger).focus();
  await page.keyboard.press("Enter");
  await waitFocus(page, "menubar-item:Email link");
  await page.keyboard.press("ArrowLeft");
  await page.locator(subContent).waitFor({ state: "detached" });
  await settle(page);
  assert.match(await focused(page), /^menubar-sub-trigger:/);
  assert.deepEqual(await triggerStates(page), ["File:open", "Edit:closed", "View:closed"]);
  assert.deepEqual((await log(page, "value-change")).map((e) => e.value), ["file"]);
  assert.deepEqual((await log(page, "open-change")).map((e) => e.open), [true, false]);
});

browserTest("menubar: hovering another trigger while a menu is open switches to it; hovering with all closed does nothing", async ({ open }) => {
  const page = await open("closed__default");
  await trigger(page, "Edit").hover();
  await settle(page);
  assert.equal(await page.locator(content).count(), 0, "control: hover alone does not open");
  await clickOpen(page, "File");
  await trigger(page, "Edit").hover();
  await openTrigger(page, "Edit").waitFor();
  assert.deepEqual(await triggerStates(page), ["File:closed", "Edit:open", "View:closed"]);
  assert.match(await openContent(page).textContent(), /Undo/);
  await waitFocus(page, "menubar-content");
});

// --- closing and focus return ----------------------------------------------------------------------------------------

browserTest("menubar: Escape closes and returns the focus to the trigger of the open menu", async ({ open }) => {
  const page = await open("closed__default");
  await record(page);
  await keyOpen(page, "File");
  await page.keyboard.press("ArrowRight");
  await openTrigger(page, "Edit").waitFor();
  await waitFocus(page, "menubar-content");
  await page.keyboard.press("Escape");
  await page.locator(content).waitFor({ state: "detached" });
  await waitFocus(page, "menubar-trigger:Edit");
  assert.equal(await trigger(page, "Edit").getAttribute("aria-expanded"), "false");
  assert.equal(await trigger(page, "Edit").getAttribute("tabindex"), "0");
  assert.deepEqual((await log(page, "escape-key-down")).map((e) => [e.slot, e.cancelable]), [["menubar-content", true]]);
  assert.equal((await log(page, "value-change")).at(-1).value, "");
});

browserTest("menubar: a caller preventDefault on escape-key-down keeps the menu open", async ({ open }) => {
  const page = await open("closed__default");
  await record(page, { prevent: ["escape-key-down"] });
  await keyOpen(page, "File");
  await page.keyboard.press("Escape");
  await waitLog(page, "escape-key-down");
  await settle(page);
  assert.equal(await openContent(page).count(), 1);
  assert.equal(await trigger(page, "File").getAttribute("data-state"), "open");
});

browserTest("menubar: an outside click closes and dispatches pointer-down-outside then interact-outside", async ({ open }) => {
  const page = await open("dismiss__outside-click");
  await record(page);
  await clickOpen(page, "File");
  await page.click(outside);
  await page.locator(content).waitFor({ state: "detached" });
  const names = (await log(page)).map((e) => e.name);
  assert.ok(names.includes("pointer-down-outside") && names.indexOf("pointer-down-outside") < names.indexOf("interact-outside"), names.join(","));
  assert.equal(await trigger(page, "File").getAttribute("aria-expanded"), "false");
  assert.equal((await log(page, "value-change")).at(-1).value, "");
});

// The press lands on the page background (not focusable), so no focus-outside follows it: only the prevented event decides.
const pressBackground = (page) => page.mouse.click(1240, 690);

for (const prevented of ["pointer-down-outside", "interact-outside"]) {
  browserTest(`menubar: a caller preventDefault on ${prevented} keeps the menu open after an outside press`, async ({ open }) => {
    const page = await open("dismiss__outside-click");
    await record(page, { prevent: [prevented] });
    await clickOpen(page, "File");
    await pressBackground(page);
    await waitLog(page, prevented);
    await settle(page);
    assert.equal(await trigger(page, "File").getAttribute("data-state"), "open");
    assert.equal(await openContent(page).count(), 1);
  });
}

browserTest("menubar: an outside press on the page background closes the menu (control of the prevented cases)", async ({ open }) => {
  const page = await open("dismiss__outside-click");
  await record(page);
  await clickOpen(page, "File");
  await pressBackground(page);
  await page.locator(content).waitFor({ state: "detached" });
  assert.deepEqual((await log(page)).filter((e) => e.name.endsWith("-outside")).map((e) => [e.name, e.slot, e.cancelable]),
    [["pointer-down-outside", "menubar-content", true], ["interact-outside", "menubar-content", true]]);
});

browserTest("menubar: focus moving outside closes the menu without pulling the focus back to the trigger", async ({ open }) => {
  const page = await open("dismiss__outside-click");
  await clickOpen(page, "File");
  await page.locator(outside).focus();
  await page.locator(content).waitFor({ state: "detached" });
  await settle(page);
  assert.equal(await page.locator(outside).evaluate((el) => el === document.activeElement), true, `focus on ${await focused(page)}`);
});

browserTest("menubar: focus moving onto another menubar trigger keeps the open menu open", async ({ open }) => {
  const page = await open("closed__default");
  await clickOpen(page, "File");
  await trigger(page, "View").focus();
  await settle(page);
  assert.equal(await focused(page), "menubar-trigger:View", "control: the focus did move");
  assert.deepEqual(await triggerStates(page), ["File:open", "Edit:closed", "View:closed"]);
  assert.equal(await openContent(page).count(), 1);
});

browserTest("menubar: a window blur closes the open menu", async ({ open }) => {
  const page = await open("closed__default");
  await clickOpen(page, "File");
  await page.evaluate(() => window.dispatchEvent(new Event("blur")));
  await page.locator(content).waitFor({ state: "detached" });
  assert.equal(await trigger(page, "File").getAttribute("data-state"), "closed");
});

browserTest("menubar: a controlled value only dispatches value-change; Escape and ArrowRight keep the DOM as rendered", async ({ open }) => {
  const page = await open("open__controlled-value-stays-on-escape");
  await record(page);
  assert.equal(await trigger(page, "File").getAttribute("data-state"), "open", "precondition: File open from the value");
  await openContent(page).focus();
  await page.keyboard.press("Escape");
  await waitLog(page, "value-change");
  await page.keyboard.press("ArrowRight");
  await waitLog(page, "value-change", 2);
  await settle(page);
  assert.deepEqual((await log(page, "value-change")).map((e) => e.value), ["", "edit"]);
  assert.deepEqual(await triggerStates(page), ["File:open", "Edit:closed", "View:closed"]);
  assert.equal(await openContent(page).count(), 1);
});

// --- checkbox and radio items ----------------------------------------------------------------------------------------

browserTest("menubar: a checkbox item click dispatches select then checked-change with the next state, and closes", async ({ open }) => {
  const page = await open("checkbox__click-select");
  await record(page);
  await page.locator("[data-slot=menubar-checkbox-item][data-state=checked]").click();
  await page.locator(content).waitFor({ state: "detached" });
  const entries = (await log(page)).filter((e) => ["select", "checked-change"].includes(e.name));
  assert.deepEqual(entries.map((e) => [e.name, e.slot, e.cancelable, e.checked]), [
    ["select", "menubar-checkbox-item", true, undefined],
    ["checked-change", "menubar-checkbox-item", false, false]
  ]);
  assert.deepEqual((await log(page, "value-change")).map((e) => [e.slot, e.value]), [["menubar", ""]]);
});

browserTest("menubar: a prevented select keeps the menu open, checked-change still fires and the checked state stays controlled", async ({ open }) => {
  const page = await open("checkbox__click-select");
  await record(page, { prevent: ["select"] });
  const unchecked = page.locator("[data-slot=menubar-checkbox-item][data-state=unchecked]").first();
  const label = await unchecked.textContent();
  await unchecked.click();
  await waitLog(page, "checked-change");
  await settle(page);
  assert.deepEqual((await log(page, "checked-change")).map((e) => e.checked), [true]);
  assert.equal(await openContent(page).count(), 1);
  assert.equal(await page.locator("[data-slot=menubar-checkbox-item]", { hasText: label }).getAttribute("data-state"), "unchecked");
});

browserTest("menubar: a radio item click dispatches value-change with its value on the radio item, then the menubar closes", async ({ open }) => {
  const page = await open("radio__click-select");
  await record(page);
  await page.locator("[data-slot=menubar-radio-item][data-chadcn--menubar-value=luis]").click();
  await page.locator(content).waitFor({ state: "detached" });
  assert.deepEqual((await log(page, "value-change")).map((e) => [e.slot, e.value]), [["menubar-radio-item", "luis"], ["menubar", ""]]);
});

// --- disconnect and Turbo cache --------------------------------------------------------------------------------------

browserTest("menubar: removing the host while open leaves nothing behind and no live listeners; reinserting it works again", async ({ open }) => {
  const page = await open("dismiss__outside-click");
  await clickOpen(page, "File");
  assert.ok((await page.locator("[data-radix-focus-guard]").count()) > 0, "precondition: focus guards installed");
  const removed = await page.evaluate(async (selector) => {
    const el = document.querySelector(selector);
    window.__host = { el, parent: el.parentNode, next: el.nextSibling };
    el.remove();
    await new Promise((resolve) => setTimeout(resolve));
    window.__after = [];
    el.addEventListener("chadcn--menubar:value-change", () => window.__after.push("value-change"));
    return {
      contents: document.querySelectorAll("[data-slot=menubar-content]").length,
      wrappers: document.querySelectorAll("[data-radix-popper-content-wrapper]").length,
      guards: document.querySelectorAll("[data-radix-focus-guard]").length,
      pointerEvents: document.body.style.pointerEvents,
      hidden: document.querySelectorAll("[aria-hidden=true]").length
    };
  }, host(CONTROLLER));
  assert.deepEqual(removed, { contents: 0, wrappers: 0, guards: 0, pointerEvents: "", hidden: 0 });
  // Document and window listeners are gone: keys, presses and a blur reach no controller (it would report on its detached host).
  await page.keyboard.press("Escape");
  await page.click(outside);
  await page.evaluate(() => window.dispatchEvent(new Event("blur")));
  await settle(page);
  assert.deepEqual(await page.evaluate(() => window.__after), []);
  await page.evaluate(async () => {
    const { el, parent, next } = window.__host;
    parent.insertBefore(el, next);
    await new Promise((resolve) => setTimeout(resolve));
  });
  await settle(page);
  assert.ok((await page.locator(content).count()) <= 1, "no duplicate content after reconnect");
  await trigger(page, "View").click();
  await openTrigger(page, "View").waitFor();
  assert.equal(await page.locator(content).count(), 1);
  assert.match(await openContent(page).textContent(), /Zoom In/);
});

browserTest("menubar: a reconnected menubar roves and opens again", async ({ open }) => {
  const page = await open("closed__default");
  await reconnect(page, CONTROLLER);
  await settle(page);
  await trigger(page, "File").focus();
  await page.keyboard.press("ArrowRight");
  await waitFocus(page, "menubar-trigger:Edit");
  await page.keyboard.press("Enter");
  await openContent(page).waitFor();
  await waitFocus(page, "menubar-item:Undo");
  assert.equal(await page.locator(content).count(), 1);
});

browserTest("menubar: turbo:before-cache while open leaves a closed snapshot; the restored host connects closed and opens again", async ({ open }) => {
  const page = await open("closed__default");
  await keyOpen(page, "File");
  assert.equal(await page.locator(content).count(), 1, "precondition: open");
  const html = await snapshot(page, CONTROLLER);
  assert.equal(await page.locator(content).count(), 0, "no portaled content when the snapshot is taken");
  assert.equal(await countIn(page, html, "[data-state=open]"), 0);
  assert.equal(await countIn(page, html, "[aria-expanded=true]"), 0);
  assert.equal(await countIn(page, html, "[aria-controls]"), 0);
  assert.equal(await countIn(page, html, '[data-chadcn--menubar-value-value=""]'), 1);
  await restore(page, CONTROLLER, html);
  assert.equal(await page.locator(content).count(), 0, "restored closed");
  assert.deepEqual(await triggerStates(page), ["File:closed", "Edit:closed", "View:closed"]);
  await trigger(page, "Edit").click();
  await openContent(page).waitFor();
  assert.equal(await trigger(page, "Edit").getAttribute("aria-expanded"), "true");
});
