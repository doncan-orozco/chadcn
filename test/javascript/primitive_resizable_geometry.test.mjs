import { assert, primitiveTest } from "./primitives_support.mjs";

// Rect and pointer math of the resizable group, called directly: plain rects and points in, numbers and rects out.

const fields = (rect) => [rect.x, rect.y, rect.width, rect.height];

primitiveTest("resizable_geometry: makeRect has the DOMRect fields, normalised for a negative size", async (page) => {
  const rects = await page.evaluate(async () => {
    const { makeRect } = await import("chadcn/primitives/resizable_geometry");
    const agreesWithDomRect = (rect) => {
      const domRect = new DOMRect(rect.x, rect.y, rect.width, rect.height);
      return ["left", "right", "top", "bottom"].every((key) => domRect[key] === rect[key]);
    };
    return { negative: makeRect(10, 20, -4, -6), agrees: [makeRect(10, 20, -4, -6), makeRect(1, 2, 3, 4)].every(agreesWithDomRect) };
  });
  assert.deepEqual(rects.negative, { x: 10, y: 20, width: -4, height: -6, left: 6, right: 10, top: 14, bottom: 20 });
  assert.equal(rects.agrees, true);
});

primitiveTest("resizable_geometry: expandRect centres a thin target on its width", async (page) => {
  const rects = await page.evaluate(async () => {
    const { expandRect, makeRect } = await import("chadcn/primitives/resizable_geometry");
    return {
      expanded: expandRect({ minimum: 10, rect: makeRect(100, 0, 2, 50) }),
      untouched: expandRect({ minimum: 0, rect: makeRect(100, 0, 2, 50) }),
    };
  });
  assert.deepEqual(rects.expanded, { x: 96, y: 0, width: 10, height: 50, left: 96, right: 106, top: 0, bottom: 50 });
  assert.equal(rects.untouched.width, 2);
});

primitiveTest("resizable_geometry: expandRect centres a thin target on its height", async (page) => {
  const rect = await page.evaluate(async () => {
    const { expandRect, makeRect } = await import("chadcn/primitives/resizable_geometry");
    return expandRect({ minimum: 10, rect: makeRect(0, 100, 50, 2) });
  });
  assert.deepEqual(rect, { x: 0, y: 96, width: 50, height: 10, left: 0, right: 50, top: 96, bottom: 106 });
});

primitiveTest("resizable_geometry: pointerDistance is zero inside a rect and the gap outside", async (page) => {
  const distances = await page.evaluate(async () => {
    const { makeRect, pointerDistance } = await import("chadcn/primitives/resizable_geometry");
    const rect = makeRect(0, 0, 10, 10);
    return { inside: pointerDistance({ x: 5, y: 5 }, rect), outside: pointerDistance({ x: 20, y: 30 }, rect) };
  });
  assert.deepEqual(distances, { inside: { x: 0, y: 0 }, outside: { x: 10, y: 20 } });
});

primitiveTest("resizable_geometry: closestRect picks the rect nearest the target along the orientation", async (page) => {
  const closest = await page.evaluate(async () => {
    const { closestRect, makeRect } = await import("chadcn/primitives/resizable_geometry");
    const first = makeRect(0, 0, 10, 10);
    const second = makeRect(50, 0, 10, 10);
    const below = makeRect(0, 50, 10, 10);
    const coordinates = ({ x, y, width, height }) => [x, y, width, height];
    return {
      horizontal: coordinates(closestRect({ orientation: "horizontal", rects: [first, second], targetRect: makeRect(40, 0, 4, 4) })),
      vertical: coordinates(closestRect({ orientation: "vertical", rects: [first, below], targetRect: makeRect(0, 40, 4, 4) })),
      firstIsNotAlwaysChosen: coordinates(closestRect({ orientation: "vertical", rects: [first, below], targetRect: makeRect(0, 2, 4, 4) })),
    };
  });
  assert.deepEqual(closest, { horizontal: [50, 0, 10, 10], vertical: [0, 50, 10, 10], firstIsNotAlwaysChosen: [0, 0, 10, 10] });
});

primitiveTest("resizable_geometry: closestRect with no rects reports that none was found", async (page) => {
  const message = await page.evaluate(async () => {
    const { closestRect, makeRect } = await import("chadcn/primitives/resizable_geometry");
    try { closestRect({ orientation: "horizontal", rects: [], targetRect: makeRect(0, 0, 1, 1) }) } catch (error) { return error.message }
  });
  assert.equal(message, "No rect found");
});

primitiveTest("resizable_geometry: nearestRegion hits only inside a region and lets the last one win a tie (horizontal)", async (page) => {
  const found = await page.evaluate(async () => {
    const { makeRect, nearestRegion } = await import("chadcn/primitives/resizable_geometry");
    const right = makeRect(50, 0, 10, 10);
    const regions = [{ name: "left", rect: makeRect(0, 0, 10, 10) }, { name: "right", rect: right }, { name: "twin", rect: right }];
    const summary = ({ region, hit }) => ({ name: region.name, hit });
    return {
      hit: summary(nearestRegion({ orientation: "horizontal", point: { x: 55, y: 5 }, regions })),
      miss: summary(nearestRegion({ orientation: "horizontal", point: { x: 20, y: 5 }, regions })),
      none: nearestRegion({ orientation: "vertical", point: { x: 0, y: 0 }, regions: [] }),
    };
  });
  assert.deepEqual(found.hit, { name: "twin", hit: true });
  assert.deepEqual(found.miss, { name: "left", hit: false });
  assert.deepEqual(found.none, { region: undefined, hit: false });
});

primitiveTest("resizable_geometry: nearestRegion hits only inside a region and lets the last one win a tie (vertical)", async (page) => {
  const found = await page.evaluate(async () => {
    const { makeRect, nearestRegion } = await import("chadcn/primitives/resizable_geometry");
    const bottom = makeRect(0, 50, 10, 10);
    const regions = [{ name: "top", rect: makeRect(0, 0, 10, 10) }, { name: "bottom", rect: bottom }, { name: "twin", rect: bottom }];
    const summary = ({ region, hit }) => ({ name: region.name, hit });
    return {
      hit: summary(nearestRegion({ orientation: "vertical", point: { x: 5, y: 55 }, regions })),
      miss: summary(nearestRegion({ orientation: "vertical", point: { x: 5, y: 20 }, regions })),
    };
  });
  assert.deepEqual(found.hit, { name: "twin", hit: true });
  assert.deepEqual(found.miss, { name: "top", hit: false });
});

primitiveTest("resizable_geometry: pointerDelta is the move since pointerdown in percent of the group", async (page) => {
  const deltas = await page.evaluate(async () => {
    const { pointerDelta } = await import("chadcn/primitives/resizable_geometry");
    return {
      horizontal: pointerDelta({ orientation: "horizontal", point: { x: 140, y: 0 }, origin: { x: 100, y: 0 }, axisSize: 400 }),
      vertical: pointerDelta({ orientation: "vertical", point: { x: 0, y: 30 }, origin: { x: 0, y: 50 }, axisSize: 200 }),
    };
  });
  assert.deepEqual(deltas, { horizontal: 10, vertical: -10 });
});

primitiveTest("resizable_geometry: pointerDelta without an origin goes to the limit on the side the pointer left", async (page) => {
  const deltas = await page.evaluate(async () => {
    const { pointerDelta } = await import("chadcn/primitives/resizable_geometry");
    return {
      before: pointerDelta({ orientation: "horizontal", point: { x: -3, y: 0 }, axisSize: 400 }),
      after: pointerDelta({ orientation: "vertical", point: { x: 0, y: 900 }, axisSize: 400 }),
    };
  });
  assert.deepEqual(deltas, { before: -100, after: 100 });
});

primitiveTest("resizable_geometry: previewOffsets is the running sum of the panels' growth in pixels", async (page) => {
  const offsets = await page.evaluate(async () => {
    const { previewOffsets } = await import("chadcn/primitives/resizable_geometry");
    return previewOffsets({ itemIds: ["a", "b", "c"], layout: { a: 40, b: 30, c: 30 }, initialLayout: { a: 30, b: 40, c: 30 }, axisSize: 400 });
  });
  assert.deepEqual(offsets, [40, 0, 0]);
});

primitiveTest("resizable_geometry: previewRect keeps a separator's rect inside the group and collapses a gap to a line (horizontal)", async (page) => {
  const rects = await page.evaluate(async () => {
    const { makeRect, previewRect } = await import("chadcn/primitives/resizable_geometry");
    const bounds = makeRect(100, 50, 400, 100);
    const scroll = { left: 0, top: 0, clientLeft: 0, clientTop: 0 };
    const rect = makeRect(290, 50, 10, 100);
    return {
      separator: previewRect({ horizontal: true, rect, separator: {}, bounds, scroll }),
      gap: previewRect({ horizontal: true, rect, separator: undefined, bounds, scroll }),
    };
  });
  assert.deepEqual(fields(rects.separator), [190, 0, 10, 100]);
  assert.deepEqual(fields(rects.gap), [195, 0, 0, 100]);
});

primitiveTest("resizable_geometry: previewRect collapses a vertical gap to a line and takes the group's scroll into account", async (page) => {
  const rects = await page.evaluate(async () => {
    const { makeRect, previewRect } = await import("chadcn/primitives/resizable_geometry");
    const bounds = makeRect(50, 100, 100, 400);
    const scroll = { left: 0, top: 0, clientLeft: 0, clientTop: 0 };
    const rect = makeRect(100, 290, 100, 10);
    return {
      gap: previewRect({ horizontal: false, rect, separator: undefined, bounds, scroll }),
      separator: previewRect({ horizontal: false, rect, separator: {}, bounds, scroll }),
      scrolled: previewRect({ horizontal: false, rect, separator: {}, bounds, scroll: { ...scroll, top: 30, clientTop: 2 } }),
    };
  });
  assert.deepEqual(fields(rects.gap), [50, 195, 100, 0]);
  assert.deepEqual(fields(rects.separator), [50, 190, 100, 10]);
  assert.deepEqual(fields(rects.scrolled), [50, 218, 100, 10]);
});

primitiveTest("resizable_geometry: sameCenter compares the centres along the main axis", async (page) => {
  const verdicts = await page.evaluate(async () => {
    const { makeRect, sameCenter } = await import("chadcn/primitives/resizable_geometry");
    return {
      same: sameCenter({ horizontal: true, a: makeRect(290, 0, 10, 1), b: makeRect(285, 0, 20, 1) }),
      different: sameCenter({ horizontal: true, a: makeRect(290, 0, 10, 1), b: makeRect(300, 0, 20, 1) }),
      vertical: sameCenter({ horizontal: false, a: makeRect(0, 290, 1, 10), b: makeRect(0, 285, 1, 20) }),
    };
  });
  assert.deepEqual(verdicts, { same: true, different: false, vertical: true });
});

primitiveTest("resizable_geometry: overlaps needs a shared area, not a shared edge", async (page) => {
  const verdicts = await page.evaluate(async () => {
    const { makeRect, overlaps } = await import("chadcn/primitives/resizable_geometry");
    return [overlaps(makeRect(0, 0, 10, 10), makeRect(5, 5, 10, 10)), overlaps(makeRect(0, 0, 10, 10), makeRect(10, 0, 10, 10))];
  });
  assert.deepEqual(verdicts, [true, false]);
});
