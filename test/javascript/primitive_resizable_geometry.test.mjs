import { assert, primitiveTest } from "./primitives_support.mjs";

// Rect and pointer math of the resizable group, called directly: plain rects and points in, numbers and rects out.

primitiveTest("resizable_geometry: makeRect has the DOMRect fields, normalised for a negative size, and expandRect centres a thin target", async (page) => {
  const result = await page.evaluate(async () => {
    const { expandRect, makeRect } = await import("chadcn/primitives/resizable_geometry");
    const same = (rect) => { const dom = new DOMRect(rect.x, rect.y, rect.width, rect.height); return ["left", "right", "top", "bottom"].every((key) => dom[key] === rect[key]) };
    return {
      negative: makeRect(10, 20, -4, -6),
      matchesDomRect: [makeRect(10, 20, -4, -6), makeRect(1, 2, 3, 4)].every(same),
      expanded: expandRect({ minimum: 10, rect: makeRect(100, 0, 2, 50) }),
      untouched: expandRect({ minimum: 0, rect: makeRect(100, 0, 2, 50) }).width,
    };
  });
  assert.deepEqual(result.negative, { x: 10, y: 20, width: -4, height: -6, left: 6, right: 10, top: 14, bottom: 20 });
  assert.equal(result.matchesDomRect, true);
  assert.deepEqual(result.expanded, { x: 96, y: 0, width: 10, height: 50, left: 96, right: 106, top: 0, bottom: 50 });
  assert.equal(result.untouched, 2);
});

primitiveTest("resizable_geometry: distances, the closest rect and the nearest region (last one wins a tie, a hit needs the point inside)", async (page) => {
  const result = await page.evaluate(async () => {
    const { closestRect, makeRect, nearestRegion, pointerDistance } = await import("chadcn/primitives/resizable_geometry");
    const left = makeRect(0, 0, 10, 10);
    const right = makeRect(50, 0, 10, 10);
    const regions = [{ name: "left", rect: left }, { name: "right", rect: right }, { name: "twin", rect: right }];
    return {
      inside: pointerDistance({ x: 5, y: 5 }, left),
      outside: pointerDistance({ x: 20, y: 30 }, left),
      closest: closestRect({ orientation: "horizontal", rects: [left, right], targetRect: makeRect(40, 0, 4, 4) }) === right,
      hit: (({ region, hit }) => ({ name: region.name, hit }))(nearestRegion({ orientation: "horizontal", point: { x: 55, y: 5 }, regions })),
      miss: (({ region, hit }) => ({ name: region.name, hit }))(nearestRegion({ orientation: "horizontal", point: { x: 20, y: 5 }, regions })),
      none: nearestRegion({ orientation: "vertical", point: { x: 0, y: 0 }, regions: [] }),
    };
  });
  assert.deepEqual(result.inside, { x: 0, y: 0 });
  assert.deepEqual(result.outside, { x: 10, y: 20 });
  assert.equal(result.closest, true);
  assert.deepEqual(result.hit, { name: "twin", hit: true });
  assert.deepEqual(result.miss, { name: "left", hit: false });
  assert.deepEqual(result.none, { region: undefined, hit: false });
});

primitiveTest("resizable_geometry: the pointer delta in percent, the push to a limit without an origin, and the preview offsets and rects", async (page) => {
  const result = await page.evaluate(async () => {
    const G = await import("chadcn/primitives/resizable_geometry");
    const bounds = G.makeRect(100, 50, 400, 100);
    const scroll = { left: 0, top: 0, clientLeft: 0, clientTop: 0 };
    return {
      deltas: [
        G.pointerDelta({ orientation: "horizontal", point: { x: 140, y: 0 }, origin: { x: 100, y: 0 }, axisSize: 400 }),
        G.pointerDelta({ orientation: "vertical", point: { x: 0, y: 30 }, origin: { x: 0, y: 50 }, axisSize: 200 }),
        G.pointerDelta({ orientation: "horizontal", point: { x: -3, y: 0 }, axisSize: 400 }),
        G.pointerDelta({ orientation: "vertical", point: { x: 0, y: 900 }, axisSize: 400 }),
      ],
      offsets: G.previewOffsets({ itemIds: ["a", "b", "c"], layout: { a: 40, b: 30, c: 30 }, initialLayout: { a: 30, b: 40, c: 30 }, axisSize: 400 }),
      separator: G.previewRect({ horizontal: true, rect: G.makeRect(290, 50, 10, 100), separator: {}, bounds, scroll }),
      gap: G.previewRect({ horizontal: true, rect: G.makeRect(290, 50, 10, 100), separator: undefined, bounds, scroll }),
      sameCenter: G.sameCenter({ horizontal: true, a: G.makeRect(290, 0, 10, 1), b: G.makeRect(285, 0, 20, 1) }),
      overlaps: [G.overlaps(G.makeRect(0, 0, 10, 10), G.makeRect(5, 5, 10, 10)), G.overlaps(G.makeRect(0, 0, 10, 10), G.makeRect(10, 0, 10, 10))],
    };
  });
  assert.deepEqual(result.deltas, [10, -10, -100, 100]);
  assert.deepEqual(result.offsets, [40, 0, 0]);
  assert.deepEqual([result.separator.x, result.separator.y, result.separator.width, result.separator.height], [190, 0, 10, 100]);
  assert.deepEqual([result.gap.x, result.gap.y, result.gap.width, result.gap.height], [195, 0, 0, 100]);
  assert.equal(result.sameCenter, true);
  assert.deepEqual(result.overlaps, [true, false]);
});
