import { assert, primitiveTest } from "./primitives_support.mjs";

// The page-wide state of the resizable groups: mounted groups, change notifications, the interaction and the imperative panel and
// group APIs, on a hand-built group record (no controller). Two 200px panels; `a` is collapsible with a 25% minimum.

const css = "body{margin:0} #g{display:flex;width:400px;height:100px} [data-panel]{flex:0 0 200px}";
const html = '<div id="g"><div id="a" data-panel></div><div id="b" data-panel></div></div>';

// Mounts the group in the store (window.axis, window.S) and records its changes in window.changes.
const mount = (page, { deferred = false } = {}) => page.evaluate(async (deferred) => {
  const S = await import("chadcn/primitives/resizable_store");
  const element = (id) => document.getElementById(id);
  const item = (id) => ({ element: element(id), id, mutableValues: {}, constraintProps: {} });
  const axis = { element: element("g"), id: "g", orientation: "horizontal", items: [item("a"), item("b")], separators: [], mutableState: { expandedItemSizes: {}, layouts: {} } };
  const derivedItemConstraints = [
    { itemId: "a", collapsible: true, collapsedSize: 0, minSize: 25, maxSize: 100 },
    { itemId: "b", collapsible: false, collapsedSize: 0, minSize: 0, maxSize: 100 },
  ];
  window.changes = [];
  S.onAxisChange(axis, (change) => window.changes.push({ layout: change.next.layout, prev: change.prev?.layout ?? null, user: change.isUserInteraction }));
  S.storeAxisState(axis, {
    defaultLayoutDeferred: deferred, derivedItemConstraints, axisSize: 400, layout: { a: 50, b: 50 }, requestedAxisSize: 400,
    requestedLayout: { a: 50, b: 50 }, separatorToItems: new Map(),
  });
  Object.assign(window, { axis, S });
}, deferred);

primitiveTest("resizable_store: a stored group is announced to its listeners, required by its object, and forgotten on unmount", async (page) => {
  await mount(page);
  const result = await page.evaluate(() => {
    const { S, axis } = window;
    const twin = { ...axis };
    let missing;
    try { S.requireState(twin) } catch (error) { missing = error.message }
    S.commitLayout(axis, S.requireState(axis), { a: 40, b: 60 }, { isUserInteraction: true });
    const state = S.requireState(axis);
    const stored = { layout: state.layout, requestedLayout: state.requestedLayout, requestedAxisSize: state.requestedAxisSize, mounted: S.mountedAxes.has(axis) };
    const dropped = S.unmountAxisState(axis);
    return { missing, stored, changes: window.changes, dropped, mounted: S.mountedAxes.has(axis) };
  });
  assert.equal(result.missing, "chadcn--resizable: group g is not mounted");
  assert.deepEqual(result.stored, { layout: { a: 40, b: 60 }, requestedLayout: { a: 40, b: 60 }, requestedAxisSize: 400, mounted: true });
  assert.deepEqual(result.changes, [
    { layout: { a: 50, b: 50 }, prev: null, user: false },
    { layout: { a: 40, b: 60 }, prev: { a: 50, b: 50 }, user: true },
  ]);
  assert.equal(result.dropped, false);
  assert.equal(result.mounted, false);
}, { css, html });

primitiveTest("resizable_store: the group API validates a set layout and returns nothing while the default layout is deferred", async (page) => {
  await mount(page);
  const result = await page.evaluate(() => {
    const api = window.S.groupApi(window.axis);
    return { before: api.getLayout(), set: api.setLayout({ a: 10, b: 30 }), after: api.getLayout() };
  });
  assert.deepEqual(result, { before: { a: 50, b: 50 }, set: { a: 25, b: 75 }, after: { a: 25, b: 75 } });

  await mount(page, { deferred: true });
  const deferred = await page.evaluate(() => {
    const api = window.S.groupApi(window.axis);
    return { get: api.getLayout(), set: api.setLayout({ a: 30, b: 70 }) };
  });
  assert.deepEqual(deferred, { get: {}, set: { a: 50, b: 50 } });
}, { css, html });

primitiveTest("resizable_store: the panel API collapses, expands back to the remembered size, resizes by any unit and reports its size", async (page) => {
  await mount(page);
  const result = await page.evaluate(() => {
    const { S, axis } = window;
    const a = S.panelApi({ axis, itemId: "a" });
    const steps = [];
    a.collapse();
    steps.push({ layout: S.requireState(axis).layout, collapsed: a.isCollapsed() });
    a.expand();
    steps.push({ layout: S.requireState(axis).layout, collapsed: a.isCollapsed() });
    a.resize("100px");
    steps.push({ layout: S.requireState(axis).layout });
    let unknown;
    try { S.panelApi({ axis, itemId: "zz" }).getSize() } catch (error) { unknown = error.message }
    return { steps, size: a.getSize(), unknown };
  });
  assert.deepEqual(result.steps, [
    { layout: { a: 0, b: 100 }, collapsed: true },
    { layout: { a: 50, b: 50 }, collapsed: false },
    { layout: { a: 25, b: 75 } },
  ]);
  assert.deepEqual(result.size, { asPercentage: 25, inPixels: 200 });
  assert.equal(result.unknown, "Layout not found for Panel zz");
}, { css, html });

primitiveTest("resizable_store: the interaction is a live binding; ending a moved drag blurs its focused separator", async (page) => {
  await page.evaluate(() => { document.body.innerHTML = '<div id="s" tabindex="0"></div>' });
  const result = await page.evaluate(async () => {
    const S = await import("chadcn/primitives/resizable_store");
    const axis = { id: "g" };
    const separator = { element: document.getElementById("s") };
    const seen = [];
    S.interactionChanges.add(({ prev, next }) => seen.push(`${prev.state}->${next.state}`));
    separator.element.focus();
    S.setInteraction({ state: "active", cursorFlags: 0, didPointerMove: false, hitRegions: [{ axis, separator }], previews: [], initialLayoutMap: new Map(), previewLayoutMap: new Map(), pointerDownAtPoint: { x: 0, y: 0 } });
    const dragging = S.isDragging(axis);
    S.updateDrag(2, [], undefined, true);
    const flags = S.interaction.cursorFlags;
    S.endInteraction();
    return { dragging, flags, state: S.interaction.state, blurred: document.activeElement !== separator.element, seen };
  });
  assert.deepEqual(result, { dragging: true, flags: 2, state: "inactive", blurred: true, seen: ["inactive->active", "active->active", "active->inactive"] });
});
