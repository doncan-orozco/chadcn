import { assert, primitiveTest } from "./primitives_support.mjs";

// The document pointer listeners of the resizable groups, driven by real mouse input on a hand-built group (no controller): hover
// cursor sheet, a drag that commits on release, double-click reset and the reference-counted listeners. Two 200px panels around
// a 2px separator at x = 200..202; the panels follow the stored layout through a change listener.

const css = "body{margin:0} #g{display:flex;width:402px;height:100px} #s{flex:0 0 2px}";
const html = '<div id="g"><div id="a" data-panel></div><div id="s" data-separator tabindex="0"></div><div id="b" data-panel></div></div>';

const mount = (page) => page.evaluate(async () => {
  const S = await import("chadcn/primitives/resizable_store");
  const P = await import("chadcn/primitives/resizable_pointer");
  const M = await import("chadcn/primitives/resizable_measure");
  const element = (id) => document.getElementById(id);
  const item = (id) => ({
    element: element(id), id, mutableValues: {},
    constraintProps: { groupResizeBehavior: "preserve-relative-size", collapsedSize: "0%", collapsible: false, maxSize: "100%", minSize: "0%", defaultSize: id === "a" ? "50%" : undefined, disabled: false },
  });
  const axis = {
    element: element("g"), id: "g", orientation: "horizontal", disabled: false, resizePreviewMode: "panel",
    resizeTargetMinimumSize: { coarse: 20, fine: 10 }, mutableState: { disableCursor: false, expandedItemSizes: {}, layouts: {} },
    items: [item("a"), item("b")], separators: [{ element: element("s"), id: "s", disabled: false, disableDoubleClick: false }],
  };
  const paint = (layout) => axis.items.forEach(({ element, id }) => { element.style.flex = `${layout[id]} 1 0` });
  window.changes = [];
  S.onAxisChange(axis, ({ next, isUserInteraction }) => { paint(next.layout); window.changes.push({ a: Math.round(next.layout.a), user: isUserInteraction }) });
  paint({ a: 50, b: 50 });
  const separatorToItems = new Map(M.hitRegionsOf({ axis, includeDisabled: true }).map((region) => [region.separator, region.items]));
  S.storeAxisState(axis, {
    defaultLayoutDeferred: false, derivedItemConstraints: M.measureConstraints(axis), axisSize: 400, layout: { a: 50, b: 50 }, requestedAxisSize: 400,
    requestedLayout: { a: 50, b: 50 }, separatorToItems,
  });
  P.retainDocument(document);
  const cursor = () => [...document.adoptedStyleSheets].flatMap((sheet) => [...sheet.cssRules].map((rule) => rule.cssText)).join("");
  Object.assign(window, { axis, S, P, cursor });
});

primitiveTest("resizable_pointer: hovering a separator sets the cursor sheet and leaving it clears the sheet", async (page) => {
  await mount(page);
  await page.mouse.move(201, 50);
  const hover = await page.evaluate(() => ({ state: window.S.interaction.state, cursor: window.cursor() }));
  await page.mouse.move(100, 50);
  const away = await page.evaluate(() => ({ state: window.S.interaction.state, cursor: window.cursor() }));
  assert.equal(hover.state, "hover");
  assert.match(hover.cursor, /cursor: ew-resize !important/);
  assert.deepEqual(away, { state: "inactive", cursor: "" });
}, { css, html });

primitiveTest("resizable_pointer: a drag focuses the separator, moves the layout with the pointer and announces a user interaction on release", async (page) => {
  await mount(page);
  await page.mouse.move(201, 50);
  await page.mouse.down();
  const pressed = await page.evaluate(() => ({ state: window.S.interaction.state, focused: document.activeElement.id }));
  await page.mouse.move(241, 50);
  const moving = await page.evaluate(() => Math.round(window.S.requireState(window.axis).layout.a));
  await page.mouse.up();
  const result = await page.evaluate(() => ({ state: window.S.interaction.state, changes: window.changes, cursor: window.cursor() }));
  assert.deepEqual(pressed, { state: "active", focused: "s" });
  assert.equal(moving, 60);
  assert.equal(result.state, "inactive");
  assert.deepEqual(result.changes.at(-1), { a: 60, user: true });
  assert.equal(result.cursor, "");
}, { css, html });

primitiveTest("resizable_pointer: a double click on the separator resets the panel that has a default size", async (page) => {
  await mount(page);
  await page.evaluate(() => window.S.groupApi(window.axis).setLayout({ a: 70, b: 30 }));
  await page.mouse.dblclick(281, 50);
  const layout = await page.evaluate(() => window.S.requireState(window.axis).layout);
  assert.deepEqual(layout, { a: 50, b: 50 });
}, { css, html });

primitiveTest("resizable_pointer: the listeners are reference counted per document and the last release drops the cursor sheet", async (page) => {
  await mount(page);
  await page.evaluate(() => window.P.retainDocument(document));
  await page.evaluate(() => window.P.releaseDocument(document));
  await page.mouse.move(201, 50);
  const retained = await page.evaluate(() => ({ state: window.S.interaction.state, sheets: document.adoptedStyleSheets.length }));
  await page.evaluate(() => window.P.releaseDocument(document));
  await page.mouse.move(100, 50);
  await page.mouse.move(201, 50);
  const released = await page.evaluate(() => ({ state: window.S.interaction.state, sheets: document.adoptedStyleSheets.length }));
  await page.evaluate(() => window.P.unmountAxis(window.axis, document));
  const unmounted = await page.evaluate(() => ({ state: window.S.interaction.state, mounted: window.S.mountedAxes.has(window.axis) }));
  assert.deepEqual(retained, { state: "hover", sheets: 1 });
  assert.deepEqual(released, { state: "hover", sheets: 0 });
  assert.deepEqual(unmounted, { state: "inactive", mounted: false });
}, { css, html });
