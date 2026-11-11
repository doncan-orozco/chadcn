import { assert, primitiveTest } from "./primitives_support.mjs";

// The pure layout engine of the resizable group (react-resizable-panels 4.14.3), called directly: numbers in, numbers out.

const load = "const L = await import(\"chadcn/primitives/resizable_layout\");";
const run = (page, body) => page.evaluate(new Function(`return (async () => { ${load} ${body} })()`));

const free = (itemId, extra = {}) => ({ itemId, collapsedSize: 0, collapsible: false, minSize: 0, maxSize: 100, ...extra });

primitiveTest("resizable_layout: round, near and compare work on three decimals; layoutsEqual compares rounded sizes per id", async (page) => {
  const result = await run(page, `return {
    round: L.round(33.33349), near: L.near(10.0004, 10), notNear: L.near(10.002, 10), tolerance: L.near(100.05, 100, 0.1),
    compare: [L.compare(1, 1.0001), L.compare(2, 1), L.compare(1, 2)],
    equal: L.layoutsEqual({ a: 50, b: 50 }, { b: 50.0001, a: 49.9999 }), differ: L.layoutsEqual({ a: 50, b: 50 }, { a: 50, c: 50 }),
    lists: L.constraintListsEqual([{ a: 1 }], [{ a: 1 }]), listsDiffer: L.constraintListsEqual([{ a: 1 }], [{ a: 2 }])
  }`);
  assert.deepEqual(result, {
    round: 33.333, near: true, notNear: false, tolerance: true, compare: [0, 1, -1], equal: true, differ: false, lists: true, listsDiffer: false,
  });
});

primitiveTest("resizable_layout: parseSize reads numbers as pixels and strings by their unit suffix (none = percent)", async (page) => {
  const result = await run(page, `return [10, "50%", "50", "200px", "2rem", "3em", "20vh", "30vw"].map(L.parseSize)`);
  assert.deepEqual(result, [[10, "px"], [50, "%"], [50, "%"], [200, "px"], [2, "rem"], [3, "em"], [20, "vh"], [30, "vw"]]);
});

primitiveTest("resizable_layout: deriveConstraints converts the size props to percent of the group, defaults at size 0", async (page) => {
  const result = await run(page, `
    const toPixels = (value) => { const [n, unit] = L.parseSize(value); return unit === "%" ? n / 100 * 400 : n };
    const items = [{ id: "a", constraintProps: { minSize: "100px", maxSize: "75%", collapsible: true, collapsedSize: "0%", defaultSize: "200px",
      groupResizeBehavior: "preserve-relative-size", disabled: false } }];
    return { sized: L.deriveConstraints({ items, axisSize: 400, toPixels }), empty: L.deriveConstraints({ items, axisSize: 0, toPixels }) }`);
  assert.deepEqual(result.sized, [{
    groupResizeBehavior: "preserve-relative-size", collapsedSize: 0, collapsedThreshold: undefined, collapsible: true, defaultSize: 50, disabled: false,
    minSize: 25, maxSize: 75, itemId: "a",
  }]);
  assert.deepEqual(result.empty, [{
    groupResizeBehavior: "preserve-relative-size", collapsedSize: 0, collapsible: true, defaultSize: undefined, disabled: false, minSize: 0, maxSize: 100, itemId: "a",
  }]);
});

primitiveTest("resizable_layout: validateSize clamps to min and max and snaps a collapsible panel past half its threshold", async (page) => {
  const result = await run(page, `
    const collapsible = { minSize: 20, maxSize: 80, collapsible: true, collapsedSize: 0 };
    const size = (constraints, prevSize, size, overrideDisabledItems = false) => L.validateSize({ itemConstraints: constraints, prevSize, size, overrideDisabledItems });
    return [
      size({ minSize: 20 }, 50, 5), size(collapsible, 50, 5), size(collapsible, 50, 15), size(collapsible, 50, 90),
      size(collapsible, 0, 8), size(collapsible, 0, 12), size({ disabled: true }, 40, 60), size({ disabled: true }, 40, 60, true)
    ]`);
  assert.deepEqual(result, [20, 0, 20, 80, 0, 20, 40, 60]);
});

primitiveTest("resizable_layout: resizeByDelta moves the pivot, respects min sizes and the keyboard snaps a collapsible panel", async (page) => {
  const result = await run(page, `
    const layout = { a: 50, b: 50 };
    const resize = (itemConstraints, delta, trigger, initialLayout = layout) =>
      L.resizeByDelta({ delta, initialLayout, prevLayout: initialLayout, itemConstraints, pivotIndices: [0, 1], trigger });
    return {
      pointer: resize([${JSON.stringify(free("a"))}, ${JSON.stringify(free("b"))}], 10, "mouse-or-touch"),
      clamped: resize([${JSON.stringify(free("a"))}, ${JSON.stringify(free("b", { minSize: 45 }))}], 10, "mouse-or-touch"),
      zero: resize([${JSON.stringify(free("a"))}, ${JSON.stringify(free("b"))}], 0, "keyboard") === layout,
      snap: resize([${JSON.stringify(free("a"))}, ${JSON.stringify(free("b", { minSize: 20, collapsible: true }))}], 5, "keyboard", { a: 80, b: 20 }),
      disabled: resize([${JSON.stringify(free("a", { disabled: true }))}, ${JSON.stringify(free("b"))}], 10, "mouse-or-touch"),
      imperative: resize([${JSON.stringify(free("a", { disabled: true }))}, ${JSON.stringify(free("b"))}], 10, "imperative-api")
    }`);
  assert.deepEqual(result, {
    pointer: { a: 60, b: 40 }, clamped: { a: 55, b: 45 }, zero: true, snap: { a: 100, b: 0 }, disabled: { a: 50, b: 50 }, imperative: { a: 60, b: 40 },
  });
});

primitiveTest("resizable_layout: validateLayout normalises to 100, pushes clamped space to the other panels and rejects a wrong panel count", async (page) => {
  const result = await run(page, `
    const constraints = [${JSON.stringify(free("a"))}, ${JSON.stringify(free("b", { minSize: 60 }))}];
    let error;
    try { L.validateLayout({ layout: { a: 100 }, itemConstraints: constraints }) } catch (e) { error = e.message }
    return {
      normalised: L.validateLayout({ layout: { a: 30, b: 30 }, itemConstraints: [${JSON.stringify(free("a"))}, ${JSON.stringify(free("b"))}] }),
      clamped: L.validateLayout({ layout: { a: 50, b: 50 }, itemConstraints: constraints }), error
    }`);
  assert.deepEqual(result, { normalised: { a: 50, b: 50 }, clamped: { a: 40, b: 60 }, error: "Invalid 2 panel layout: 100%" });
});

primitiveTest("resizable_layout: ariaValues gives the separator's now, min and max as the panel before it can reach them", async (page) => {
  const result = await run(page, `return L.ariaValues({
    layout: { a: 50, b: 50 }, itemConstraints: [${JSON.stringify(free("a", { minSize: 10, maxSize: 70 }))}, ${JSON.stringify(free("b"))}], itemId: "a", itemIndex: 0
  })`);
  assert.deepEqual(result, { valueControls: "a", valueMax: 70, valueMin: 10, valueNow: 50 });
});

primitiveTest("resizable_layout: the initial layout prefers the remembered layout, then a complete default layout, then the default sizes", async (page) => {
  const result = await run(page, `
    const itemConstraints = [{ itemId: "a", defaultSize: 30 }, { itemId: "b" }, { itemId: "c" }];
    const itemIds = ["a", "b", "c"];
    const state = (extra) => ({ defaultLayout: undefined, layouts: {}, ...extra });
    return {
      defaults: L.defaultItemLayout(itemConstraints),
      remembered: L.initialLayout({ itemIds, itemConstraints, mutableState: state({ layouts: { "a,b,c": { a: 1, b: 1, c: 98 } }, defaultLayout: { a: 10, b: 10, c: 80 } }) }),
      given: L.initialLayout({ itemIds, itemConstraints, mutableState: state({ defaultLayout: { a: 10, b: 10, c: 80 } }) }),
      partial: L.initialLayout({ itemIds, itemConstraints, mutableState: state({ defaultLayout: { a: 10, b: 90 } }) }),
      loose: L.looseLayout({ itemIds: ["a", "b"], layout: { a: 1, b: 3 } })
    }`);
  assert.deepEqual(result, {
    defaults: { a: 30, b: 35, c: 35 }, remembered: { a: 1, b: 1, c: 98 }, given: { a: 10, b: 10, c: 80 }, partial: { a: 30, b: 35, c: 35 }, loose: { a: 25, b: 75 },
  });
});

primitiveTest("resizable_layout: rescaleForGroupSize keeps the pixels of preserve-pixel-size panels when the group grows", async (page) => {
  const result = await run(page, `
    const items = [{ id: "a", constraintProps: { groupResizeBehavior: "preserve-pixel-size" } }, { id: "b", constraintProps: {} }];
    const prevLayout = { a: 25, b: 75 };
    return {
      grown: L.rescaleForGroupSize({ items, prevLayout, prevAxisSize: 400, nextAxisSize: 800 }),
      same: L.rescaleForGroupSize({ items, prevLayout, prevAxisSize: 400, nextAxisSize: 400 }) === prevLayout,
      relativeOnly: L.rescaleForGroupSize({ items: [items[1]], prevLayout: { b: 100 }, prevAxisSize: 400, nextAxisSize: 800 })
    }`);
  assert.deepEqual(result, { grown: { a: 12.5, b: 87.5 }, same: true, relativeOnly: { b: 100 } });
});

primitiveTest("resizable_layout: recordExpandedSize remembers the requested layout and the size a panel had before it collapsed", async (page) => {
  const result = await run(page, `
    const mutableState = { layouts: {}, expandedItemSizes: {} };
    const derivedItemConstraints = [${JSON.stringify(free("a", { collapsible: true, minSize: 20 }))}, ${JSON.stringify(free("b"))}];
    L.recordExpandedSize({ derivedItemConstraints, itemIds: ["a", "b"], mutableState, layout: { a: 0, b: 100 }, prevLayout: { a: 30, b: 70 }, requestedLayout: { a: 0, b: 100 } });
    return mutableState`);
  assert.deepEqual(result, { layouts: { "a,b": { a: 0, b: 100 } }, expandedItemSizes: { a: 30 } });
});

primitiveTest("resizable_layout: panelResizeLayout moves the separator after a panel, before the last one, and lets the last one fill collapsed space", async (page) => {
  const result = await run(page, `
    const itemConstraints = [${JSON.stringify(free("a", { collapsible: true }))}, ${JSON.stringify(free("b"))}];
    const resize = (itemId, nextSize, prevLayout) => L.panelResizeLayout({ itemId, itemIds: ["a", "b"], nextSize, prevLayout, itemConstraints });
    return { first: resize("a", 30, { a: 50, b: 50 }), last: resize("b", 30, { a: 50, b: 50 }), fill: resize("b", 60, { a: 0, b: 100 }) }`);
  assert.deepEqual(result, { first: { a: 30, b: 70 }, last: { a: 70, b: 30 }, fill: { a: 0, b: 100 } });
});
