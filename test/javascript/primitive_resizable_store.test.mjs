import { assert, primitiveTest } from "./primitives_support.mjs";

// The page-wide state of the resizable groups: mounted groups, change notifications, the interaction and the imperative panel and
// group APIs, on a hand-built group record (no controller). Two 200px panels; `a` is collapsible with a 25% minimum.

const css = "body{margin:0} #g{display:flex;width:400px;height:100px} [data-panel]{flex:0 0 200px}";
const html = '<div id="g"><div id="a" data-panel></div><div id="b" data-panel></div></div>';

// Mounts the group in the store (window.axis, window.store) and records its changes in window.changes.
const mount = (page, { deferred = false, maxB = 100 } = {}) => page.evaluate(async ({ deferred, maxB }) => {
  const store = await import("chadcn/primitives/resizable_store");
  const element = (id) => document.getElementById(id);
  const item = (id) => ({ element: element(id), id, mutableValues: {}, constraintProps: {} });
  const axis = { element: element("g"), id: "g", orientation: "horizontal", items: [item("a"), item("b")], separators: [], mutableState: { expandedItemSizes: {}, layouts: {} } };
  const derivedItemConstraints = [
    { itemId: "a", collapsible: true, collapsedSize: 0, minSize: 25, maxSize: 100 },
    { itemId: "b", collapsible: false, collapsedSize: 0, minSize: 0, maxSize: maxB },
  ];
  window.changes = [];
  store.onAxisChange(axis, (change) => window.changes.push({ layout: change.next.layout, prev: change.prev?.layout ?? null, user: change.isUserInteraction }));
  store.storeAxisState(axis, {
    defaultLayoutDeferred: deferred, derivedItemConstraints, axisSize: 400, layout: { a: 50, b: 50 }, requestedAxisSize: 400,
    requestedLayout: { a: 50, b: 50 }, separatorToItems: new Map(),
  });
  Object.assign(window, { axis, store });
}, { deferred, maxB });

primitiveTest("resizable_store: a stored group is announced to its listeners and required by its object", async (page) => {
  await mount(page);
  const stored = await page.evaluate(() => {
    const { store, axis } = window;
    const twin = { ...axis };
    let missing;
    try { store.requireState(twin) } catch (error) { missing = error.message }
    store.commitLayout(axis, store.requireState(axis), { a: 40, b: 60 }, { isUserInteraction: true });
    const state = store.requireState(axis);
    return {
      missing, layout: state.layout, requestedLayout: state.requestedLayout, requestedAxisSize: state.requestedAxisSize, mounted: store.mountedAxes.has(axis),
      changes: window.changes,
    };
  });
  assert.equal(stored.missing, "chadcn--resizable: group g is not mounted");
  assert.deepEqual(stored.layout, { a: 40, b: 60 });
  assert.deepEqual(stored.requestedLayout, { a: 40, b: 60 });
  assert.equal(stored.requestedAxisSize, 400);
  assert.equal(stored.mounted, true);
  assert.deepEqual(stored.changes, [
    { layout: { a: 50, b: 50 }, prev: null, user: false },
    { layout: { a: 40, b: 60 }, prev: { a: 50, b: 50 }, user: true },
  ]);
}, { css, html });

primitiveTest("resizable_store: unmounting a group forgets it", async (page) => {
  await mount(page);
  const unmounted = await page.evaluate(() => {
    const { store, axis } = window;
    const mountedBefore = store.mountedAxes.has(axis);
    const tookPartInInteraction = store.unmountAxisState(axis);
    return { mountedBefore, tookPartInInteraction, mountedAfter: store.mountedAxes.has(axis) };
  });
  assert.deepEqual(unmounted, { mountedBefore: true, tookPartInInteraction: false, mountedAfter: false });
}, { css, html });

primitiveTest("resizable_store: the group API validates a set layout", async (page) => {
  await mount(page);
  const layouts = await page.evaluate(() => {
    const api = window.store.groupApi(window.axis);
    return { before: api.getLayout(), set: api.setLayout({ a: 10, b: 30 }), after: api.getLayout() };
  });
  assert.deepEqual(layouts, { before: { a: 50, b: 50 }, set: { a: 25, b: 75 }, after: { a: 25, b: 75 } });
}, { css, html });

primitiveTest("resizable_store: the group API returns nothing while the default layout is deferred", async (page) => {
  await mount(page, { deferred: true });
  const layouts = await page.evaluate(() => {
    const api = window.store.groupApi(window.axis);
    return { get: api.getLayout(), set: api.setLayout({ a: 30, b: 70 }) };
  });
  assert.deepEqual(layouts, { get: {}, set: { a: 50, b: 50 } });
}, { css, html });

primitiveTest("resizable_store: the panel API collapses and expands back to the remembered size", async (page) => {
  await mount(page);
  const steps = await page.evaluate(() => {
    const { store, axis } = window;
    const panelA = store.panelApi({ axis, itemId: "a" });
    const record = () => ({ layout: store.requireState(axis).layout, collapsed: panelA.isCollapsed() });
    panelA.collapse();
    const collapsed = record();
    panelA.expand();
    return { collapsed, expanded: record() };
  });
  assert.deepEqual(steps, {
    collapsed: { layout: { a: 0, b: 100 }, collapsed: true },
    expanded: { layout: { a: 50, b: 50 }, collapsed: false },
  });
}, { css, html });

primitiveTest("resizable_store: the panel API resizes by any unit and reports its size", async (page) => {
  await mount(page);
  const resized = await page.evaluate(() => {
    const { store, axis } = window;
    const panelA = store.panelApi({ axis, itemId: "a" });
    panelA.resize("100px");
    return { layout: store.requireState(axis).layout, size: panelA.getSize() };
  });
  assert.deepEqual(resized.layout, { a: 25, b: 75 });
  assert.deepEqual(resized.size, { asPercentage: 25, inPixels: 200 });
}, { css, html });

primitiveTest("resizable_store: the panel API throws for a panel that is not in the group", async (page) => {
  await mount(page);
  const message = await page.evaluate(() => {
    try { window.store.panelApi({ axis: window.axis, itemId: "zz" }).getSize() } catch (error) { return error.message }
  });
  assert.equal(message, "Layout not found for Panel zz");
}, { css, html });

primitiveTest("resizable_store: a panel that is not collapsible ignores collapse and expand", async (page) => {
  await mount(page);
  const outcome = await page.evaluate(() => {
    const { store, axis } = window;
    const panelB = store.panelApi({ axis, itemId: "b" });
    panelB.collapse();
    panelB.expand();
    return { layout: store.requireState(axis).layout, collapsed: panelB.isCollapsed(), changes: window.changes.length };
  });
  assert.deepEqual(outcome, { layout: { a: 50, b: 50 }, collapsed: false, changes: 1 });
}, { css, html });

primitiveTest("resizable_store: a resize stops at the maximum size of the panel that grows", async (page) => {
  await mount(page, { maxB: 60 });
  const resized = await page.evaluate(() => {
    const { store, axis } = window;
    const panelA = store.panelApi({ axis, itemId: "a" });
    panelA.resize("40px");
    return { layout: store.requireState(axis).layout, size: panelA.getSize().asPercentage };
  });
  assert.deepEqual(resized, { layout: { a: 40, b: 60 }, size: 40 });
}, { css, html });

primitiveTest("resizable_store: the interaction is a live binding; ending a moved drag blurs its focused separator", async (page) => {
  const drag = await page.evaluate(async () => {
    const store = await import("chadcn/primitives/resizable_store");
    const axis = { id: "g" };
    const separator = { element: document.getElementById("s") };
    const seen = [];
    store.interactionChanges.add(({ prev, next }) => seen.push(`${prev.state}->${next.state}`));
    separator.element.focus();
    store.setInteraction({
      state: "active", cursorFlags: 0, didPointerMove: false, hitRegions: [{ axis, separator }], previews: [], initialLayoutMap: new Map(),
      previewLayoutMap: new Map(), pointerDownAtPoint: { x: 0, y: 0 },
    });
    const dragging = store.isDragging(axis);
    const cursorFlags = 2;
    const previews = [];
    const previewLayoutMap = undefined;
    const didPointerMove = true;
    store.updateDrag(cursorFlags, previews, previewLayoutMap, didPointerMove);
    const flags = store.interaction.cursorFlags;
    const focusedWhileDragging = document.activeElement === separator.element;
    store.endInteraction();
    return { dragging, flags, focusedWhileDragging, state: store.interaction.state, blurred: document.activeElement !== separator.element, seen };
  });
  assert.deepEqual(drag, {
    dragging: true, flags: 2, focusedWhileDragging: true, state: "inactive", blurred: true, seen: ["inactive->active", "active->active", "active->inactive"],
  });
}, { html: '<div id="s" tabindex="0"></div>' });
