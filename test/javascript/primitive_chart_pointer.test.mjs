import { assert, primitiveTest } from "./primitives_support.mjs";

const TICKS = [{ index: 0, coordinate: 30 }, { index: 1, coordinate: 80 }, { index: 2, coordinate: 130 }];

primitiveTest("chart_pointer: nearestTickIndex picks the band, the midpoint belonging to the lower tick", async (page) => {
  const result = await page.evaluate(async (ticks) => {
    const { nearestTickIndex } = await import("chadcn/primitives/chart_pointer");
    return [0, 30, 55, 55.5, 105, 105.01, 400].map((coordinate) => nearestTickIndex(coordinate, ticks));
  }, TICKS);
  assert.deepEqual(result, [0, 0, 0, 1, 1, 2, 2]);
});

primitiveTest("chart_pointer: ticks are ordered by coordinate first (a reversed axis) and the answer is the tick's index", async (page) => {
  const result = await page.evaluate(async () => {
    const { nearestTickIndex } = await import("chadcn/primitives/chart_pointer");
    const reversed = [{ index: 0, coordinate: 130 }, { index: 1, coordinate: 80 }, { index: 2, coordinate: 30 }];
    return [20, 80, 120].map((coordinate) => nearestTickIndex(coordinate, reversed));
  });
  assert.deepEqual(result, [2, 1, 0]);
});

primitiveTest("chart_pointer: one tick or none answers 0, a missing coordinate answers 0", async (page) => {
  const result = await page.evaluate(async () => {
    const { nearestTickIndex } = await import("chadcn/primitives/chart_pointer");
    return [nearestTickIndex(999, [{ index: 7, coordinate: 5 }]), nearestTickIndex(5, []), nearestTickIndex(null, [{ index: 0, coordinate: 1 }, { index: 1, coordinate: 2 }])];
  });
  assert.deepEqual(result, [0, 0, 0]);
});

primitiveTest("chart_pointer: pointerInPlot includes the borders", async (page) => {
  const result = await page.evaluate(async () => {
    const { pointerInPlot } = await import("chadcn/primitives/chart_pointer");
    const plot = { x: 5, y: 5, width: 310, height: 160 };
    return [[5, 5], [315, 165], [4, 50], [316, 50], [50, 4], [50, 166], [100, 100]].map(([x, y]) => pointerInPlot({ x, y }, plot));
  });
  assert.deepEqual(result, [true, true, false, false, false, false, true]);
});

primitiveTest("chart_pointer: relativePointer rounds to the element and corrects a CSS scale", async (page) => {
  const result = await page.evaluate(async () => {
    const { relativePointer } = await import("chadcn/primitives/chart_pointer");
    const element = document.getElementById("plot");
    const rect = element.getBoundingClientRect();
    const plain = relativePointer({ currentTarget: element, clientX: rect.left + 10.4, clientY: rect.top + 20.6 });
    element.style.transform = "scale(0.5)";
    element.style.transformOrigin = "0 0";
    const scaledRect = element.getBoundingClientRect();
    const scaled = relativePointer({ currentTarget: element, clientX: scaledRect.left + 50, clientY: scaledRect.top + 25 });
    return { plain, scaled };
  });
  assert.deepEqual(result.plain, { x: 10, y: 21 });
  assert.deepEqual(result.scaled, { x: 100, y: 50 });
}, { html: '<div id="plot" style="position:absolute;left:30px;top:40px;width:200px;height:100px"></div>' });
