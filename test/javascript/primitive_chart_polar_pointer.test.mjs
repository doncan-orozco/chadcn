import { assert, primitiveTest } from "./primitives_support.mjs";

// The radar of tooltip__radar-hover (320x200, margin 5, outer radius 80% of 95) and the radial bar chart of tooltip__radial-hover
// (inner radius 30, outer 100), with the tick coordinates recharts gives their tooltip axes.
const RADAR = { cx: 160, cy: 100, innerRadius: 0, outerRadius: 76, startAngle: 90, endAngle: -270 };
const RADAR_TICKS = [90, 30, -30, -90, -150, -210].map((coordinate, index) => ({ index, coordinate }));
const RADIAL = { cx: 160, cy: 100, innerRadius: 30, outerRadius: 100, startAngle: 0, endAngle: 360 };
const RADIAL_TICKS = [41.6667, 65, 88.3333].map((coordinate, index) => ({ index, coordinate }));

const round = (value) => Math.round(value * 1e4) / 1e4;

primitiveTest("chart_polar_pointer: polarPointer is the radius and angle of a point inside the sector, null outside or at the center", async (page) => {
  const result = await page.evaluate(async ({ radar, radial }) => {
    const { polarPointer } = await import("chadcn/primitives/chart_polar_pointer");
    const points = [[160, 50], [203, 75], [118, 125], [160, 10], [160, 100]].map(([x, y]) => polarPointer({ x, y }, radar));
    return { radar: points, radial: [[201, 100], [160, 100], [160, 35]].map(([x, y]) => polarPointer({ x, y }, radial)) };
  }, { radar: RADAR, radial: RADIAL });
  const pairs = (list) => list.map((point) => point && [round(point.radius), round(point.angle)]);
  // (118, 125) is at 210.76 degrees and (160, 50) at 90: the sector from 90 to -270 reaches them as -149.24 and -270 (`reverseFormatAngleOfSector`).
  assert.deepEqual(pairs(result.radar), [[50, -270], [49.7393, 30.1735], [48.8774, -149.2373], null, null]);
  assert.deepEqual(pairs(result.radial), [[41, 0], null, [65, 90]]);
});

primitiveTest("chart_polar_pointer: a sector that is not a full turn rejects the angles outside it", async (page) => {
  const result = await page.evaluate(async () => {
    const { polarPointer } = await import("chadcn/primitives/chart_polar_pointer");
    const half = { cx: 100, cy: 100, innerRadius: 0, outerRadius: 80, startAngle: 180, endAngle: 0 };
    return [[100, 50], [100, 150], [40, 100]].map(([x, y]) => polarPointer({ x, y }, half)?.angle ?? null);
  });
  assert.deepEqual(result, [90, null, 180]);
});

primitiveTest("chart_polar_pointer: polarTickIndex walks a full turn of angle ticks around the circle", async (page) => {
  const result = await page.evaluate(async (ticks) => {
    const { polarTickIndex } = await import("chadcn/primitives/chart_polar_pointer");
    return [90, 61, 59, 30.17, 0, -149.24, -180, -239, -241, -269].map((angle) => polarTickIndex(angle, ticks, { angleAxis: true, range: [90, -270] }));
  }, RADAR_TICKS);
  assert.deepEqual(result, [0, 0, 1, 1, 2, 4, 5, 5, 0, 0]);
});

primitiveTest("chart_polar_pointer: radius ticks, and angle ticks over less than a turn, are bands along one direction", async (page) => {
  const result = await page.evaluate(async (ticks) => {
    const { polarTickIndex } = await import("chadcn/primitives/chart_polar_pointer");
    const half = [{ index: 0, coordinate: 165 }, { index: 1, coordinate: 90 }, { index: 2, coordinate: 15 }];
    return {
      radius: [31, 53, 54, 77, 99].map((radius) => polarTickIndex(radius, ticks, { angleAxis: false, range: [30, 100] })),
      half: [170, 120, 60, 10].map((angle) => polarTickIndex(angle, half, { angleAxis: true, range: [180, 0] })),
      single: polarTickIndex(42, [{ index: 3, coordinate: 50 }], { angleAxis: false, range: [0, 100] }),
    };
  }, RADIAL_TICKS);
  assert.deepEqual(result, { radius: [0, 0, 1, 2, 2], half: [0, 1, 1, 2], single: 0 });
});

primitiveTest("chart_polar_pointer: the active coordinate is the pointer's radius on the tick's angle (centric) or the tick's radius at the pointer's angle (radial)", async (page) => {
  const result = await page.evaluate(async ({ radar, radial }) => {
    const { polarActiveCoordinate } = await import("chadcn/primitives/chart_polar_pointer");
    return [
      polarActiveCoordinate("centric", 30, { radius: 49.7393, angle: 30.1735 }, radar),
      polarActiveCoordinate("radial", 41.6667, { radius: 41, angle: 0 }, radial),
      polarActiveCoordinate("radial", 65, { radius: 65, angle: 90 }, radial),
    ];
  }, { radar: RADAR, radial: RADIAL });
  assert.deepEqual(result.map(({ x, y }) => [round(x), round(y)]), [[203.0755, 75.1303], [201.6667, 100], [160, 35]]);
});

primitiveTest("chart_polar_pointer: polarToCartesian runs counterclockwise from 3 o'clock, y down", async (page) => {
  const result = await page.evaluate(async () => {
    const { polarToCartesian } = await import("chadcn/primitives/chart_polar_pointer");
    return [0, 90, 180, 270].map((angle) => polarToCartesian(10, 10, 5, angle));
  });
  assert.deepEqual(result.map(({ x, y }) => [round(x), round(y)]), [[15, 10], [10, 5], [5, 10], [10, 15]]);
});
