import { assert, primitiveTest } from "./primitives_support.mjs";

// The pure layout engine of the resizable group (react-resizable-panels 4.14.3), called directly: numbers in, numbers out.
// Fixtures are built here and passed to the page; each test imports the exports it uses inside page.evaluate.

const free = (itemId, extra = {}) => ({ itemId, collapsedSize: 0, collapsible: false, minSize: 0, maxSize: 100, ...extra });
const pair = ({ first = {}, second = {} } = {}) => [free("a", first), free("b", second)];
const relativeItems = [
  { id: "a", constraintProps: { groupResizeBehavior: "preserve-relative-size" } },
  { id: "b", constraintProps: { groupResizeBehavior: "preserve-relative-size" } },
];

primitiveTest("resizable_layout: round keeps three decimals", async (page) => {
  const rounded = await page.evaluate(async () => {
    const { round } = await import("chadcn/primitives/resizable_layout");
    return round(33.33349);
  });
  assert.equal(rounded, 33.333);
});

primitiveTest("resizable_layout: near compares rounded values within a tolerance", async (page) => {
  const verdicts = await page.evaluate(async () => {
    const { near } = await import("chadcn/primitives/resizable_layout");
    return { within: near(10.0004, 10), outside: near(10.002, 10), tolerated: near(100.05, 100, 0.1), notTolerated: near(100.2, 100, 0.1) };
  });
  assert.deepEqual(verdicts, { within: true, outside: false, tolerated: true, notTolerated: false });
});

primitiveTest("resizable_layout: compare orders rounded values", async (page) => {
  const orders = await page.evaluate(async () => {
    const { compare } = await import("chadcn/primitives/resizable_layout");
    return { equal: compare(1, 1.0001), greater: compare(2, 1), lesser: compare(1, 2) };
  });
  assert.deepEqual(orders, { equal: 0, greater: 1, lesser: -1 });
});

primitiveTest("resizable_layout: layoutsEqual compares rounded sizes per id", async (page) => {
  const verdicts = await page.evaluate(async () => {
    const { layoutsEqual } = await import("chadcn/primitives/resizable_layout");
    return {
      rounded: layoutsEqual({ a: 50, b: 50 }, { b: 50.0001, a: 49.9999 }),
      otherId: layoutsEqual({ a: 50, b: 50 }, { a: 50, c: 50 }),
      otherSize: layoutsEqual({ a: 50, b: 50 }, { a: 60, b: 40 }),
      otherCount: layoutsEqual({ a: 100 }, { a: 50, b: 50 }),
    };
  });
  assert.deepEqual(verdicts, { rounded: true, otherId: false, otherSize: false, otherCount: false });
});

primitiveTest("resizable_layout: constraintListsEqual compares each record by value", async (page) => {
  const verdicts = await page.evaluate(async () => {
    const { constraintListsEqual } = await import("chadcn/primitives/resizable_layout");
    return {
      same: constraintListsEqual([{ a: 1 }], [{ a: 1 }]),
      differs: constraintListsEqual([{ a: 1 }], [{ a: 2 }]),
      otherLength: constraintListsEqual([{ a: 1 }], [{ a: 1 }, { a: 1 }]),
    };
  });
  assert.deepEqual(verdicts, { same: true, differs: false, otherLength: false });
});

primitiveTest("resizable_layout: parseSize reads numbers as pixels and strings by their unit suffix (none = percent)", async (page) => {
  const sizes = await page.evaluate(async () => {
    const { parseSize } = await import("chadcn/primitives/resizable_layout");
    return [10, "50%", "50", "200px", "2rem", "3em", "20vh", "30vw"].map(parseSize);
  });
  assert.deepEqual(sizes, [[10, "px"], [50, "%"], [50, "%"], [200, "px"], [2, "rem"], [3, "em"], [20, "vh"], [30, "vw"]]);
});

primitiveTest("resizable_layout: deriveConstraints converts the size props to percent of the group", async (page) => {
  const items = [{ id: "a", constraintProps: { minSize: "100px", maxSize: "75%", collapsible: true, collapsedSize: "0%", defaultSize: "200px",
    groupResizeBehavior: "preserve-relative-size", disabled: false } }];
  const sized = await page.evaluate(async (fixtureItems) => {
    const { deriveConstraints, parseSize } = await import("chadcn/primitives/resizable_layout");
    const toPixels = (value) => { const [number, unit] = parseSize(value); return unit === "%" ? number / 100 * 400 : number };
    return deriveConstraints({ items: fixtureItems, axisSize: 400, toPixels });
  }, items);
  assert.deepEqual(sized, [{
    groupResizeBehavior: "preserve-relative-size", collapsedSize: 0, collapsedThreshold: undefined, collapsible: true, defaultSize: 50, disabled: false,
    minSize: 25, maxSize: 75, itemId: "a",
  }]);
});

primitiveTest("resizable_layout: deriveConstraints at group size 0 gives open constraints and no default size", async (page) => {
  const items = [{ id: "a", constraintProps: { minSize: "100px", maxSize: "75%", collapsible: true, defaultSize: "200px",
    groupResizeBehavior: "preserve-relative-size", disabled: false } }];
  const empty = await page.evaluate(async (fixtureItems) => {
    const { deriveConstraints } = await import("chadcn/primitives/resizable_layout");
    return deriveConstraints({ items: fixtureItems, axisSize: 0, toPixels: () => { throw new Error("no conversion at size 0") } });
  }, items);
  assert.deepEqual(empty, [{
    groupResizeBehavior: "preserve-relative-size", collapsedSize: 0, collapsible: true, defaultSize: undefined, disabled: false, minSize: 0, maxSize: 100, itemId: "a",
  }]);
});

primitiveTest("resizable_layout: validateSize clamps below the minimum and above the maximum", async (page) => {
  const collapsible = { minSize: 20, maxSize: 80, collapsible: true, collapsedSize: 0 };
  const sizes = await page.evaluate(async ({ plain, withCollapse }) => {
    const { validateSize } = await import("chadcn/primitives/resizable_layout");
    return {
      belowMinimum: validateSize({ itemConstraints: plain, prevSize: 50, size: 5, overrideDisabledItems: false }),
      aboveMaximum: validateSize({ itemConstraints: withCollapse, prevSize: 50, size: 90, overrideDisabledItems: false }),
    };
  }, { plain: { minSize: 20 }, withCollapse: collapsible });
  assert.deepEqual(sizes, { belowMinimum: 20, aboveMaximum: 80 });
});

primitiveTest("resizable_layout: validateSize snaps a collapsible panel to collapsed or to its minimum around the threshold", async (page) => {
  const collapsible = { minSize: 20, maxSize: 80, collapsible: true, collapsedSize: 0 };
  const sizes = await page.evaluate(async (itemConstraints) => {
    const { validateSize } = await import("chadcn/primitives/resizable_layout");
    const validated = (prevSize, size) => validateSize({ itemConstraints, prevSize, size, overrideDisabledItems: false });
    return {
      farBelow: validated(50, 5), nearMinimum: validated(50, 15), collapsedStaysBelowThreshold: validated(0, 8), collapsedExpandsPastThreshold: validated(0, 12),
    };
  }, collapsible);
  assert.deepEqual(sizes, { farBelow: 0, nearMinimum: 20, collapsedStaysBelowThreshold: 0, collapsedExpandsPastThreshold: 20 });
});

primitiveTest("resizable_layout: validateSize keeps a disabled panel's size unless disabled panels are overridden", async (page) => {
  const sizes = await page.evaluate(async () => {
    const { validateSize } = await import("chadcn/primitives/resizable_layout");
    const itemConstraints = { disabled: true };
    return {
      kept: validateSize({ itemConstraints, prevSize: 40, size: 60, overrideDisabledItems: false }),
      overridden: validateSize({ itemConstraints, prevSize: 40, size: 60, overrideDisabledItems: true }),
    };
  });
  assert.deepEqual(sizes, { kept: 40, overridden: 60 });
});

primitiveTest("resizable_layout: resizeByDelta moves the separator right and left", async (page) => {
  const layouts = await page.evaluate(async (itemConstraints) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const layout = { a: 50, b: 50 };
    const resize = (delta) => resizeByDelta({ delta, initialLayout: layout, prevLayout: layout, itemConstraints, pivotIndices: [0, 1], trigger: "mouse-or-touch" });
    return { positive: resize(10), negative: resize(-10) };
  }, pair());
  assert.deepEqual(layouts, { positive: { a: 60, b: 40 }, negative: { a: 40, b: 60 } });
});

primitiveTest("resizable_layout: resizeByDelta stops at a minimum size in both directions", async (page) => {
  const layouts = await page.evaluate(async ({ shrinkingB, shrinkingA }) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const layout = { a: 50, b: 50 };
    const resize = (delta, itemConstraints) => resizeByDelta({ delta, initialLayout: layout, prevLayout: layout, itemConstraints, pivotIndices: [0, 1], trigger: "mouse-or-touch" });
    return { positive: resize(10, shrinkingB), negative: resize(-10, shrinkingA) };
  }, { shrinkingB: pair({ second: { minSize: 45 } }), shrinkingA: pair({ first: { minSize: 45 } }) });
  assert.deepEqual(layouts, { positive: { a: 55, b: 45 }, negative: { a: 45, b: 55 } });
});

primitiveTest("resizable_layout: resizeByDelta returns the very same layout for a zero delta", async (page) => {
  const same = await page.evaluate(async (itemConstraints) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const layout = { a: 50, b: 50 };
    return resizeByDelta({ delta: 0, initialLayout: layout, prevLayout: layout, itemConstraints, pivotIndices: [0, 1], trigger: "keyboard" }) === layout;
  }, pair());
  assert.equal(same, true);
});

primitiveTest("resizable_layout: resizeByDelta moves the pivot [1, 2] of a three-panel group and leaves the first panel alone", async (page) => {
  const itemConstraints = [free("a"), free("b"), free("c")];
  const layouts = await page.evaluate(async (constraints) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const layout = { a: 30, b: 40, c: 30 };
    const resize = (delta) => resizeByDelta({ delta, initialLayout: layout, prevLayout: layout, itemConstraints: constraints, pivotIndices: [1, 2], trigger: "mouse-or-touch" });
    return { positive: resize(10), negative: resize(-10) };
  }, itemConstraints);
  assert.deepEqual(layouts, { positive: { a: 30, b: 50, c: 20 }, negative: { a: 30, b: 30, c: 40 } });
});

primitiveTest("resizable_layout: a pointer drag beyond the collapsed threshold moves a panel below its minimum by the whole span; within it the panel stays or collapses", async (page) => {
  const collapsibleA = pair({ first: { collapsible: true, minSize: 20, collapsedThreshold: 4 } });
  const collapsibleB = pair({ second: { collapsible: true, minSize: 20, collapsedThreshold: 4 } });
  const layouts = await page.evaluate(async ({ growingA, growingB }) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const resize = (layout, delta, itemConstraints) => resizeByDelta({ delta, initialLayout: layout, prevLayout: layout, itemConstraints, pivotIndices: [0, 1], trigger: "mouse-or-touch" });
    return {
      rightBeyondThreshold: resize({ a: 10, b: 90 }, 6, growingA),
      rightWithinThreshold: resize({ a: 10, b: 90 }, 3, growingA),
      leftBeyondThreshold: resize({ a: 90, b: 10 }, -6, growingB),
      leftWithinThreshold: resize({ a: 90, b: 10 }, -3, growingB),
    };
  }, { growingA: collapsibleA, growingB: collapsibleB });
  assert.deepEqual(layouts, {
    rightBeyondThreshold: { a: 30, b: 70 },
    rightWithinThreshold: { a: 10, b: 90 },
    leftBeyondThreshold: { a: 70, b: 30 },
    leftWithinThreshold: { a: 100, b: 0 },
  });
});

primitiveTest("resizable_layout: without a collapsed threshold a pointer drag of exactly half the span moves the panel only when dragging left", async (page) => {
  const collapsibleA = pair({ first: { collapsible: true, minSize: 20 } });
  const collapsibleB = pair({ second: { collapsible: true, minSize: 20 } });
  const layouts = await page.evaluate(async ({ growingA, growingB }) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const resize = (layout, delta, itemConstraints) => resizeByDelta({ delta, initialLayout: layout, prevLayout: layout, itemConstraints, pivotIndices: [0, 1], trigger: "mouse-or-touch" });
    return { right: resize({ a: 5, b: 95 }, 10, growingA), left: resize({ a: 95, b: 5 }, -10, growingB) };
  }, { growingA: collapsibleA, growingB: collapsibleB });
  assert.deepEqual(layouts, { right: { a: 5, b: 95 }, left: { a: 75, b: 25 } });
});

primitiveTest("resizable_layout: the keyboard snaps a collapsible panel that sits at its minimum to collapsed", async (page) => {
  const layout = await page.evaluate(async (itemConstraints) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const initialLayout = { a: 80, b: 20 };
    return resizeByDelta({ delta: 5, initialLayout, prevLayout: initialLayout, itemConstraints, pivotIndices: [0, 1], trigger: "keyboard" });
  }, pair({ second: { minSize: 20, collapsible: true } }));
  assert.deepEqual(layout, { a: 100, b: 0 });
});

primitiveTest("resizable_layout: the keyboard expands a collapsed panel straight to its minimum", async (page) => {
  const layouts = await page.evaluate(async ({ collapsible, fixed }) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const initialLayout = { a: 0, b: 100 };
    const press = (itemConstraints) => resizeByDelta({ delta: 5, initialLayout, prevLayout: initialLayout, itemConstraints, pivotIndices: [0, 1], trigger: "keyboard" });
    return { collapsed: press(collapsible), notCollapsible: press(fixed) };
  }, { collapsible: pair({ first: { collapsible: true, minSize: 20 } }), fixed: pair({ first: { minSize: 20 } }) });
  assert.deepEqual(layouts, { collapsed: { a: 20, b: 80 }, notCollapsible: { a: 0, b: 100 } });
});

primitiveTest("resizable_layout: a disabled panel resists the pointer but not the imperative API", async (page) => {
  const layouts = await page.evaluate(async (itemConstraints) => {
    const { resizeByDelta } = await import("chadcn/primitives/resizable_layout");
    const layout = { a: 50, b: 50 };
    const resize = (trigger) => resizeByDelta({ delta: 10, initialLayout: layout, prevLayout: layout, itemConstraints, pivotIndices: [0, 1], trigger });
    return { pointer: resize("mouse-or-touch"), imperative: resize("imperative-api") };
  }, pair({ first: { disabled: true } }));
  assert.deepEqual(layouts, { pointer: { a: 50, b: 50 }, imperative: { a: 60, b: 40 } });
});

primitiveTest("resizable_layout: validateLayout normalises a layout that does not add up to 100", async (page) => {
  const normalised = await page.evaluate(async (itemConstraints) => {
    const { validateLayout } = await import("chadcn/primitives/resizable_layout");
    return validateLayout({ layout: { a: 30, b: 30 }, itemConstraints });
  }, pair());
  assert.deepEqual(normalised, { a: 50, b: 50 });
});

primitiveTest("resizable_layout: validateLayout pushes space clamped by a minimum onto the other panels", async (page) => {
  const clamped = await page.evaluate(async (itemConstraints) => {
    const { validateLayout } = await import("chadcn/primitives/resizable_layout");
    return validateLayout({ layout: { a: 50, b: 50 }, itemConstraints });
  }, pair({ second: { minSize: 60 } }));
  assert.deepEqual(clamped, { a: 40, b: 60 });
});

primitiveTest("resizable_layout: validateLayout rejects a layout with the wrong panel count", async (page) => {
  const message = await page.evaluate(async (itemConstraints) => {
    const { validateLayout } = await import("chadcn/primitives/resizable_layout");
    try { validateLayout({ layout: { a: 100 }, itemConstraints }) } catch (error) { return error.message }
  }, pair());
  assert.equal(message, "Invalid 2 panel layout: 100%");
});

primitiveTest("resizable_layout: ariaValues gives the separator's now, min and max as the panel before it can reach them", async (page) => {
  const values = await page.evaluate(async (itemConstraints) => {
    const { ariaValues } = await import("chadcn/primitives/resizable_layout");
    return ariaValues({ layout: { a: 50, b: 50 }, itemConstraints, itemId: "a", itemIndex: 0 });
  }, pair({ first: { minSize: 10, maxSize: 70 } }));
  assert.deepEqual(values, { valueControls: "a", valueMax: 70, valueMin: 10, valueNow: 50 });
});

primitiveTest("resizable_layout: ariaValues lets a collapsible panel reach its collapsed size, where a fixed one stops at its minimum", async (page) => {
  const values = await page.evaluate(async ({ collapsible, fixed }) => {
    const { ariaValues } = await import("chadcn/primitives/resizable_layout");
    const layout = { a: 50, b: 50 };
    return {
      collapsible: ariaValues({ layout, itemConstraints: collapsible, itemId: "a", itemIndex: 0 }),
      fixed: ariaValues({ layout, itemConstraints: fixed, itemId: "a", itemIndex: 0 }),
    };
  }, { collapsible: pair({ first: { collapsible: true, minSize: 20, maxSize: 70 } }), fixed: pair({ first: { minSize: 20, maxSize: 70 } }) });
  assert.deepEqual(values.collapsible, { valueControls: "a", valueMax: 70, valueMin: 0, valueNow: 50 });
  assert.deepEqual(values.fixed, { valueControls: "a", valueMax: 70, valueMin: 20, valueNow: 50 });
});

primitiveTest("resizable_layout: ariaValues for an unknown item has no min or max", async (page) => {
  const values = await page.evaluate(async (itemConstraints) => {
    const { ariaValues } = await import("chadcn/primitives/resizable_layout");
    return ariaValues({ layout: { a: 50, b: 50 }, itemConstraints, itemId: "zz", itemIndex: 0 });
  }, pair());
  assert.deepEqual(values, { valueControls: "zz", valueMax: undefined, valueMin: undefined, valueNow: undefined });
});

primitiveTest("resizable_layout: defaultItemLayout shares the rest of 100 between the panels without a default size", async (page) => {
  const layout = await page.evaluate(async () => {
    const { defaultItemLayout } = await import("chadcn/primitives/resizable_layout");
    return defaultItemLayout([{ itemId: "a", defaultSize: 30 }, { itemId: "b" }, { itemId: "c" }]);
  });
  assert.deepEqual(layout, { a: 30, b: 35, c: 35 });
});

primitiveTest("resizable_layout: rememberedOrDefaultLayout prefers the remembered layout of the panel set", async (page) => {
  const layout = await page.evaluate(async () => {
    const { rememberedOrDefaultLayout } = await import("chadcn/primitives/resizable_layout");
    return rememberedOrDefaultLayout({
      itemIds: ["a", "b", "c"], itemConstraints: [{ itemId: "a", defaultSize: 30 }, { itemId: "b" }, { itemId: "c" }],
      mutableState: { layouts: { "a,b,c": { a: 1, b: 1, c: 98 } }, defaultLayout: { a: 10, b: 10, c: 80 } },
    });
  });
  assert.deepEqual(layout, { a: 1, b: 1, c: 98 });
});

primitiveTest("resizable_layout: rememberedOrDefaultLayout uses a default layout that names every panel, else the default sizes", async (page) => {
  const layouts = await page.evaluate(async () => {
    const { rememberedOrDefaultLayout } = await import("chadcn/primitives/resizable_layout");
    const itemIds = ["a", "b", "c"];
    const itemConstraints = [{ itemId: "a", defaultSize: 30 }, { itemId: "b" }, { itemId: "c" }];
    const layoutFor = (defaultLayout) => rememberedOrDefaultLayout({ itemIds, itemConstraints, mutableState: { layouts: {}, defaultLayout } });
    return { given: layoutFor({ a: 10, b: 10, c: 80 }), partial: layoutFor({ a: 10, b: 90 }), none: layoutFor(undefined) };
  });
  assert.deepEqual(layouts, { given: { a: 10, b: 10, c: 80 }, partial: { a: 30, b: 35, c: 35 }, none: { a: 30, b: 35, c: 35 } });
});

primitiveTest("resizable_layout: looseLayout only normalises to 100", async (page) => {
  const layout = await page.evaluate(async () => {
    const { looseLayout } = await import("chadcn/primitives/resizable_layout");
    return looseLayout({ itemIds: ["a", "b"], layout: { a: 1, b: 3 } });
  });
  assert.deepEqual(layout, { a: 25, b: 75 });
});

primitiveTest("resizable_layout: rescaleForGroupSize keeps the pixels of preserve-pixel-size panels when the group grows", async (page) => {
  const items = [{ id: "a", constraintProps: { groupResizeBehavior: "preserve-pixel-size" } }, { id: "b", constraintProps: {} }];
  const grown = await page.evaluate(async (fixtureItems) => {
    const { rescaleForGroupSize } = await import("chadcn/primitives/resizable_layout");
    return rescaleForGroupSize({ items: fixtureItems, prevLayout: { a: 25, b: 75 }, prevAxisSize: 400, nextAxisSize: 800 });
  }, items);
  assert.deepEqual(grown, { a: 12.5, b: 87.5 });
});

primitiveTest("resizable_layout: rescaleForGroupSize returns the same layout when the size is unchanged or nothing keeps its pixels", async (page) => {
  const items = [{ id: "a", constraintProps: { groupResizeBehavior: "preserve-pixel-size" } }, { id: "b", constraintProps: {} }];
  const verdicts = await page.evaluate(async (fixtureItems) => {
    const { rescaleForGroupSize } = await import("chadcn/primitives/resizable_layout");
    const prevLayout = { a: 25, b: 75 };
    const relativeLayout = { b: 100 };
    return {
      sameSize: rescaleForGroupSize({ items: fixtureItems, prevLayout, prevAxisSize: 400, nextAxisSize: 400 }) === prevLayout,
      relativeOnly: rescaleForGroupSize({ items: [fixtureItems[1]], prevLayout: relativeLayout, prevAxisSize: 400, nextAxisSize: 800 }) === relativeLayout,
    };
  }, items);
  assert.deepEqual(verdicts, { sameSize: true, relativeOnly: true });
});

primitiveTest("resizable_layout: recordExpandedSize remembers the requested layout and the size a panel had before it collapsed", async (page) => {
  const mutableState = await page.evaluate(async (derivedItemConstraints) => {
    const { recordExpandedSize } = await import("chadcn/primitives/resizable_layout");
    const state = { layouts: {}, expandedItemSizes: {} };
    recordExpandedSize({ derivedItemConstraints, itemIds: ["a", "b"], mutableState: state, layout: { a: 0, b: 100 }, prevLayout: { a: 30, b: 70 }, requestedLayout: { a: 0, b: 100 } });
    return state;
  }, pair({ first: { collapsible: true, minSize: 20 } }));
  assert.deepEqual(mutableState, { layouts: { "a,b": { a: 0, b: 100 } }, expandedItemSizes: { a: 30 } });
});

primitiveTest("resizable_layout: panelResizeLayout moves the separator after a panel, or before the last one", async (page) => {
  const layouts = await page.evaluate(async (itemConstraints) => {
    const { panelResizeLayout } = await import("chadcn/primitives/resizable_layout");
    const resize = (itemId, nextSize, prevLayout) => panelResizeLayout({ itemId, itemIds: ["a", "b"], nextSize, prevLayout, itemConstraints });
    return { first: resize("a", 30, { a: 50, b: 50 }), last: resize("b", 30, { a: 50, b: 50 }) };
  }, pair({ first: { collapsible: true } }));
  assert.deepEqual(layouts, { first: { a: 30, b: 70 }, last: { a: 70, b: 30 } });
});

primitiveTest("resizable_layout: panelResizeLayout lets the last panel fill the space the collapsed panels before it leave", async (page) => {
  const layout = await page.evaluate(async (itemConstraints) => {
    const { panelResizeLayout } = await import("chadcn/primitives/resizable_layout");
    return panelResizeLayout({ itemId: "b", itemIds: ["a", "b"], nextSize: 60, prevLayout: { a: 0, b: 100 }, itemConstraints });
  }, pair({ first: { collapsible: true } }));
  assert.deepEqual(layout, { a: 0, b: 100 });
});

primitiveTest("resizable_layout: nextGroupState computes a layout deferred at group size 0 once the group has a size", async (page) => {
  const itemConstraints = [free("a", { defaultSize: 30 }), free("b")];
  const state = await page.evaluate(async ({ items, constraints }) => {
    const { nextGroupState } = await import("chadcn/primitives/resizable_layout");
    const deferred = {
      defaultLayoutDeferred: true, derivedItemConstraints: [], axisSize: 0, layout: {}, requestedAxisSize: 0, requestedLayout: {}, separatorToItems: "separators",
    };
    return nextGroupState({
      items, itemIds: ["a", "b"], mutableState: { defaultLayout: undefined, layouts: {} }, state: deferred, axisSize: 400, itemConstraints: constraints,
    });
  }, { items: relativeItems, constraints: itemConstraints });
  assert.deepEqual(state, {
    defaultLayoutDeferred: false, derivedItemConstraints: itemConstraints, axisSize: 400, layout: { a: 30, b: 70 },
    requestedAxisSize: 400, requestedLayout: { a: 30, b: 70 }, separatorToItems: "separators",
  });
});

primitiveTest("resizable_layout: nextGroupState returns undefined when the size, constraints and layout are unchanged, and a state once the size changes", async (page) => {
  const verdicts = await page.evaluate(async ({ items, constraints }) => {
    const { nextGroupState } = await import("chadcn/primitives/resizable_layout");
    const state = {
      defaultLayoutDeferred: false, derivedItemConstraints: constraints, axisSize: 400, layout: { a: 50, b: 50 }, requestedAxisSize: 400,
      requestedLayout: { a: 50, b: 50 }, separatorToItems: "separators",
    };
    const next = (axisSize, itemConstraints) => nextGroupState({ items, itemIds: ["a", "b"], mutableState: { layouts: {} }, state, axisSize, itemConstraints });
    return {
      unchanged: next(400, structuredClone(constraints)) ?? null,
      resized: next(500, constraints)?.axisSize ?? null,
      reconstrained: next(400, [{ ...constraints[0], minSize: 10 }, constraints[1]])?.derivedItemConstraints[0].minSize ?? null,
    };
  }, { items: relativeItems, constraints: pair() });
  assert.deepEqual(verdicts, { unchanged: null, resized: 500, reconstrained: 10 });
});

primitiveTest("resizable_layout: nextGroupState keeps the pixels of a preserve-pixel-size panel when the group grows", async (page) => {
  const items = [{ id: "a", constraintProps: { groupResizeBehavior: "preserve-pixel-size" } }, { id: "b", constraintProps: { groupResizeBehavior: "preserve-relative-size" } }];
  const itemConstraints = pair();
  const state = await page.evaluate(async ({ fixtureItems, constraints }) => {
    const { nextGroupState } = await import("chadcn/primitives/resizable_layout");
    const previous = {
      defaultLayoutDeferred: false, derivedItemConstraints: constraints, axisSize: 400, layout: { a: 25, b: 75 }, requestedAxisSize: 400,
      requestedLayout: { a: 25, b: 75 }, separatorToItems: "separators",
    };
    return nextGroupState({ items: fixtureItems, itemIds: ["a", "b"], mutableState: { layouts: {} }, state: previous, axisSize: 800, itemConstraints: constraints });
  }, { fixtureItems: items, constraints: itemConstraints });
  assert.deepEqual(state, {
    defaultLayoutDeferred: false, derivedItemConstraints: itemConstraints, axisSize: 800, layout: { a: 12.5, b: 87.5 },
    requestedAxisSize: 400, requestedLayout: { a: 25, b: 75 }, separatorToItems: "separators",
  });
});

primitiveTest("resizable_layout: keyboardResizedLayout returns the validated layout after the key moved the separator", async (page) => {
  const layout = await page.evaluate(async (itemConstraints) => {
    const { keyboardResizedLayout } = await import("chadcn/primitives/resizable_layout");
    return keyboardResizedLayout({ layout: { a: 50, b: 50 }, itemConstraints, pivotIndices: [0, 1], delta: 5 });
  }, pair());
  assert.deepEqual(layout, { a: 55, b: 45 });
});

primitiveTest("resizable_layout: keyboardResizedLayout returns undefined when a limit blocks the move", async (page) => {
  const verdicts = await page.evaluate(async ({ blocked, free: open }) => {
    const { keyboardResizedLayout } = await import("chadcn/primitives/resizable_layout");
    const press = (itemConstraints) => keyboardResizedLayout({ layout: { a: 50, b: 50 }, itemConstraints, pivotIndices: [0, 1], delta: 5 }) ?? null;
    return { blocked: press(blocked), open: press(open) };
  }, { blocked: pair({ second: { minSize: 50 } }), free: pair() });
  assert.deepEqual(verdicts, { blocked: null, open: { a: 55, b: 45 } });
});

primitiveTest("resizable_layout: panelSize gives the size as a percentage of the group and in pixels", async (page) => {
  const sizes = await page.evaluate(async () => {
    const { panelSize } = await import("chadcn/primitives/resizable_layout");
    return { half: panelSize({ pixels: 200, axisSize: 400 }), third: panelSize({ pixels: 100, axisSize: 300 }) };
  });
  assert.deepEqual(sizes, { half: { asPercentage: 50, inPixels: 200 }, third: { asPercentage: 33.333, inPixels: 100 } });
});
