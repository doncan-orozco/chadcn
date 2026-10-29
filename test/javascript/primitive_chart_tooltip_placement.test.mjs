import { assert, primitiveTest } from "./primitives_support.mjs";

const BASE = {
  box: { width: 100, height: 40 },
  viewBox: { x: 5, y: 5, width: 310, height: 160 },
  offset: { x: 10, y: 10 },
  position: {},
  allowEscapeViewBox: { x: false, y: false },
  reverseDirection: { x: false, y: false },
};

const place = (page, overrides) => page.evaluate(async ({ base, overrides }) => {
  const { tooltipPlacement } = await import("chadcn/primitives/chart_tooltip_placement");
  return tooltipPlacement({ ...base, ...overrides });
}, { base: BASE, overrides });

primitiveTest("chart_tooltip_placement: opens after the coordinate by the offset, on the bottom right", async (page) => {
  const result = await place(page, { coordinate: { x: 50, y: 60 } });
  assert.equal(result.transform, "translate(60px, 70px)");
  assert.deepEqual(result.classes, ["recharts-tooltip-wrapper-right", "recharts-tooltip-wrapper-bottom"]);
});

primitiveTest("chart_tooltip_placement: flips before the edge of the view box, minus the box and the offset", async (page) => {
  const result = await place(page, { coordinate: { x: 280, y: 150 } });
  assert.equal(result.transform, "translate(170px, 100px)");
  assert.deepEqual(result.classes, ["recharts-tooltip-wrapper-left", "recharts-tooltip-wrapper-top"]);
});

primitiveTest("chart_tooltip_placement: never goes before the view box origin", async (page) => {
  const result = await place(page, { coordinate: { x: 6, y: 6 }, box: { width: 400, height: 400 } });
  assert.equal(result.transform, "translate(5px, 5px)");
});

primitiveTest("chart_tooltip_placement: allowEscapeViewBox skips the clamp, reverseDirection opens before the coordinate", async (page) => {
  const escaped = await place(page, { coordinate: { x: 280, y: 150 }, allowEscapeViewBox: { x: true, y: true } });
  assert.equal(escaped.transform, "translate(290px, 160px)");
  const reversed = await place(page, { coordinate: { x: 200, y: 100 }, reverseDirection: { x: true, y: true } });
  assert.equal(reversed.transform, "translate(90px, 50px)");
  assert.deepEqual(reversed.classes, ["recharts-tooltip-wrapper-left", "recharts-tooltip-wrapper-top"]);
});

primitiveTest("chart_tooltip_placement: a numeric position fixes an axis and a non-number does not", async (page) => {
  const fixed = await place(page, { coordinate: { x: 50, y: 60 }, position: { x: 12 } });
  assert.equal(fixed.transform, "translate(12px, 70px)");
  assert.deepEqual(fixed.classes, ["recharts-tooltip-wrapper-left", "recharts-tooltip-wrapper-bottom"]);
  const ignored = await place(page, { coordinate: { x: 50, y: 60 }, position: { x: "12", y: NaN } });
  assert.equal(ignored.transform, "translate(60px, 70px)");
});

primitiveTest("chart_tooltip_placement: a box without size or no coordinate yields no transform and no classes", async (page) => {
  assert.deepEqual(await place(page, { coordinate: { x: 50, y: 60 }, box: { width: 0, height: 40 } }), { transform: null, classes: [] });
  assert.deepEqual(await place(page, { coordinate: null }), { transform: null, classes: [] });
});
