import { assert, primitiveTest, tick } from "./primitives_support.mjs";

const items = `
  <button id="a" data-radix-collection-item tabindex="-1">A</button>
  <button id="b" data-radix-collection-item tabindex="-1">B</button>
  <button id="c" data-radix-collection-item tabindex="-1" data-disabled>C</button>
  <button id="d" data-radix-collection-item tabindex="-1">D</button>`;
const html = `<button id="before">before</button><div id="group" tabindex="0" data-orientation="horizontal">${items}</div><button id="after">after</button>`;

const start = (page, options = "{}") => page.evaluate(async (options) => {
  const { rovingFocus } = await import("shadcn/primitives/roving_focus");
  window.__log = [];
  const log = window.__log;
  window.__roving = rovingFocus(document.getElementById("group"), new Function("log", `return (${options})`)(log));
}, options);
const active = (page) => page.evaluate(() => document.activeElement.id);
const tabindexes = (page) => page.evaluate(() => Object.fromEntries([...document.querySelectorAll("#group > button")].map((b) => [b.id, b.tabIndex])));
const press = async (page, key) => { await page.keyboard.press(key); await tick(page); };

primitiveTest("roving_focus: render marks the current tab stop 0, other items -1 and keeps the group tabbable", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "b" }');
  assert.deepEqual(await tabindexes(page), { a: -1, b: 0, c: -1, d: -1 });
  assert.equal(await page.evaluate(() => document.getElementById("group").tabIndex), 0);
  assert.equal(await page.evaluate(() => window.__roving.currentTabStop()), "b");
}, { html });

primitiveTest("roving_focus: arrow keys move focus and the tab stop, skipping disabled items and stopping at the edges", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "a", onCurrentTabStopIdChange: (id) => log.push(id) }');
  await page.focus("#a");
  await press(page, "ArrowRight");
  assert.equal(await active(page), "b");
  await press(page, "ArrowRight");
  assert.equal(await active(page), "d", "the disabled item is skipped");
  await press(page, "ArrowRight");
  assert.equal(await active(page), "d", "no loop: stays on the last item");
  await press(page, "Home");
  assert.equal(await active(page), "a");
  await press(page, "End");
  assert.equal(await active(page), "d");
  await press(page, "ArrowLeft");
  assert.equal(await active(page), "b");
  assert.deepEqual(await tabindexes(page), { a: -1, b: 0, c: -1, d: -1 });
  assert.deepEqual(await page.evaluate(() => window.__log), ["b", "d", "a", "d", "b"]);
}, { html });

primitiveTest("roving_focus: loop wraps around; the cross-axis arrows do nothing", async (page) => {
  await start(page, '{ orientation: "horizontal", loop: true, currentTabStopId: "d" }');
  await page.focus("#d");
  await press(page, "ArrowRight");
  assert.equal(await active(page), "a");
  await press(page, "ArrowLeft");
  assert.equal(await active(page), "d");
  await press(page, "ArrowDown");
  assert.equal(await active(page), "d");
}, { html });

primitiveTest("roving_focus: vertical orientation uses Up/Down and ignores Left/Right", async (page) => {
  await start(page, '{ orientation: "vertical", currentTabStopId: "a" }');
  await page.focus("#a");
  await press(page, "ArrowRight");
  assert.equal(await active(page), "a");
  await press(page, "ArrowDown");
  assert.equal(await active(page), "b");
}, { html });

primitiveTest("roving_focus: rtl reverses the horizontal arrows", async (page) => {
  await start(page, '{ orientation: "horizontal", dir: "rtl", currentTabStopId: "a" }');
  await page.focus("#a");
  await press(page, "ArrowLeft");
  assert.equal(await active(page), "b");
}, { html });

primitiveTest("roving_focus: modified arrows are ignored", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "a" }');
  await page.focus("#a");
  await press(page, "Shift+ArrowRight");
  assert.equal(await active(page), "a");
}, { html });

primitiveTest("roving_focus: focusing the group by keyboard forwards to the active item, then the current stop; onEntryFocus can take over", async (page) => {
  await start(page, '{ orientation: "horizontal", isActive: (el) => el.id === "d", currentTabStopId: "b" }');
  await page.focus("#group");
  assert.equal(await active(page), "d", "the active item wins");
  await page.evaluate(() => window.__roving.release());
  await page.focus("#before");
  await start(page, '{ orientation: "horizontal", currentTabStopId: "b", onEntryFocus: (e) => { log.push("entry:" + e.cancelable); e.preventDefault() } }');
  await page.focus("#group");
  assert.equal(await active(page), "group");
  assert.deepEqual(await page.evaluate(() => window.__log), ["entry:true"]);
}, { html });

primitiveTest("roving_focus: a mouse down on an item makes it the tab stop; Shift+Tab out suspends the group tab stop", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "a" }');
  await page.click("#d");
  assert.deepEqual(await tabindexes(page), { a: -1, b: -1, c: -1, d: 0 });
  await page.keyboard.press("Shift+Tab");
  assert.equal(await page.evaluate(() => document.activeElement.id), "before");
  assert.equal(await page.evaluate(() => document.getElementById("group").tabIndex), 0, "restored on focusout");
}, { html });

primitiveTest("roving_focus: reacts to items becoming disabled or being added (MutationObserver)", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "a" }');
  await page.evaluate(() => { for (const id of ["a", "b", "d"]) document.getElementById(id).setAttribute("data-disabled", "") });
  await tick(page);
  assert.equal(await page.evaluate(() => document.getElementById("group").tabIndex), -1, "no focusable item: the group is not a tab stop");
  await page.evaluate(() => { document.getElementById("group").insertAdjacentHTML("beforeend", '<button id="e" data-radix-collection-item tabindex="0">E</button>') });
  await tick(page);
  assert.deepEqual(await tabindexes(page), { a: 0, b: -1, c: -1, d: -1, e: -1 });
  assert.equal(await page.evaluate(() => document.getElementById("group").tabIndex), 0, "the new enabled item makes the group tabbable again");
}, { html });

primitiveTest("roving_focus: release() removes the listeners and the observer", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "a", onEntryFocus: () => log.push("entry") }');
  await page.evaluate(() => window.__roving.release());
  await page.focus("#a");
  await press(page, "ArrowRight");
  assert.equal(await active(page), "a");
  await page.click("#d");
  assert.equal(await page.evaluate(() => window.__roving.currentTabStop()), "a");
  await page.evaluate(() => { for (const id of ["a", "b", "d"]) document.getElementById(id).setAttribute("data-disabled", "") });
  await tick(page);
  assert.equal(await page.evaluate(() => document.getElementById("group").tabIndex), 0, "no re-render after release");
}, { html });

primitiveTest("roving_focus: after release() focusing the group fires no onEntryFocus and does not forward focus", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "a", onEntryFocus: () => log.push("entry") }');
  await page.evaluate(() => window.__roving.release());
  await page.focus("#group");
  assert.equal(await active(page), "group");
  assert.deepEqual(await page.evaluate(() => window.__log), []);
}, { html });

primitiveTest("roving_focus: after release() the focusout and keydown listeners are gone", async (page) => {
  await start(page, '{ orientation: "horizontal", currentTabStopId: "a" }');
  await page.evaluate(() => window.__roving.release());
  await page.evaluate(() => { document.getElementById("group").tabIndex = -1 });
  await page.focus("#a");
  await page.focus("#before");
  assert.equal(await page.evaluate(() => document.getElementById("group").tabIndex), -1, "focusout no longer re-renders");
  await page.focus("#a");
  await press(page, "ArrowRight");
  assert.equal(await active(page), "a", "keydown no longer moves focus");
}, { html });
