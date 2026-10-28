// Regenerates the expected values of the private chart math tests (scale/oracle.json, shape/oracle.json) from the real d3 and
// recharts in dev/react-shadcn-catalog (npm ci there first):  node test/chadcn/chart/shape/oracle.mjs
// The Ruby tests never run node; they read the committed JSON. A recharts or d3 bump regenerates it and the diff is the review.
import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const catalog = path.resolve(here, "../../../../dev/react-shadcn-catalog");
const require = createRequire(path.join(catalog, "package.json"));
const d3 = async (name) => import(pathToFileURL(path.join(catalog, "node_modules", name, "src/index.js")).href);
const { ticks, tickIncrement } = await d3("d3-array");
const { scaleLinear, scaleBand, scalePoint } = await d3("d3-scale");
const shape = await d3("d3-shape");
const recharts = (file) => require(path.join(catalog, "node_modules/recharts/lib", file));
const { getNiceTickValues, getTickValuesFixedDomain } = recharts("util/scale/getNiceTickValues.js");
const { Sector } = recharts("shape/Sector.js");
const { computePieSectors } = recharts("polar/Pie.js");
const { getStackedData } = recharts("util/ChartUtils.js");
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");

// recharts shape/Curve.js getPath (lib/ and es6/ are the same logic), driven by the ESM d3-shape 3.2 the browser build uses: the CJS
// victory-vendor copy under lib/ predates path digits and would print full precision instead of the 3 digits of the rendered DOM.
const FACTORIES = { linear: shape.curveLinear, linearClosed: shape.curveLinearClosed, monotone: [shape.curveMonotoneX, shape.curveMonotoneY], natural: shape.curveNatural, step: shape.curveStep, stepBefore: shape.curveStepBefore, stepAfter: shape.curveStepAfter, basis: shape.curveBasis, basisClosed: shape.curveBasisClosed, basisOpen: shape.curveBasisOpen, bumpX: shape.curveBumpX, bumpY: shape.curveBumpY, bump: [shape.curveBumpX, shape.curveBumpY] };
const wellBehaved = (n) => typeof n === "number" && Number.isFinite(n);
const defined = (p) => wellBehaved(p.x) && wellBehaved(p.y);
const getPath = ({ type = "linear", points = [], baseLine, layout, connectNulls = false }) => {
  let factory = FACTORIES[type] || shape.curveLinear;
  if (Array.isArray(factory)) factory = factory[layout === "vertical" ? 1 : 0];
  const formatted = connectNulls ? points.filter(defined) : points;
  if (Array.isArray(baseLine)) {
    const withBase = points.map((p, i) => ({ ...p, base: baseLine[i] }));
    const areaDefined = (d) => d.base != null && defined(d.base) && defined(d);
    const fn = layout === "vertical" ? shape.area().y((p) => p.y).x1((p) => p.x).x0((d) => d.base.x) : shape.area().x((p) => p.x).y1((p) => p.y).y0((d) => d.base.y);
    return fn.defined(areaDefined).curve(factory)(connectNulls ? withBase.filter(areaDefined) : withBase);
  }
  let fn;
  if (layout === "vertical" && typeof baseLine === "number") fn = shape.area().y((p) => p.y).x1((p) => p.x).x0(baseLine);
  else if (typeof baseLine === "number") fn = shape.area().x((p) => p.x).y1((p) => p.y).y0(baseLine);
  else fn = shape.line().x((p) => p.x).y((p) => p.y);
  return fn.defined(defined).curve(factory)(formatted);
};

const num = (v) => (Number.isFinite(v) ? v : String(v));

// ---- scale --------------------------------------------------------------------------------------------------------------
const tickCases = [[0, 186, 5], [0, 186, 10], [-50, 120, 5], [-3, 3, 4], [0, 1, 10], [0.001, 0.009, 5], [7, 7, 5], [0, 305, 5], [0, 505, 5], [1, 100, 3], [-1e3, 1e4, 6], [0.5, 0.75, 2], [0, 0.1, 5]];
const niceCases = [[0, 186, 5], [0, 305, 5], [0, 505, 5], [-50, 120, 5], [0.13, 0.87, 5], [7, 7, 5], [3, 97, 10], [-0.5, 12.5, 4]];
const linearCalls = [{ domain: [0, 186], range: [180, 5], values: [0, 50, 186, 200, -10] }, { domain: [10, 10], range: [0, 100], values: [10, 11] }, { domain: [-5, 5], range: [0, 300], values: [-5, 0, 2.5] }];
const bandCases = [
  { count: 5, range: [0, 300], opts: {} },
  { count: 3, range: [5, 315], opts: { padding: 0.1 } },
  { count: 4, range: [0, 100], opts: { paddingInner: 0.2, paddingOuter: 0.5, align: 0.2 } },
  { count: 1, range: [0, 100], opts: { padding: 0.3 } },
  { count: 0, range: [0, 100], opts: {} },
  { count: 6, range: [300, 0], opts: { padding: 0.2 } },
];
const scalesOut = {
  ticks: tickCases.map(([a, b, c]) => ({ start: a, stop: b, count: c, ticks: ticks(a, b, c), increment: tickIncrement(a, b, c) })),
  descending_ticks: [[186, 0, 5], [5, -5, 4]].map(([a, b, c]) => ({ start: a, stop: b, count: c, ticks: ticks(a, b, c) })),
  nice: niceCases.map(([a, b, c]) => ({ start: a, stop: b, count: c, domain: scaleLinear().domain([a, b]).nice(c).domain() })),
  linear: linearCalls.map((c) => { const s = scaleLinear().domain(c.domain).range(c.range); return { ...c, mapped: c.values.map((v) => num(s(v))) }; }),
  band: bandCases.map((c) => {
    const dom = [...Array(c.count).keys()]; const s = scaleBand().domain(dom).range(c.range);
    for (const [k, v] of Object.entries(c.opts)) s[k](v);
    return { ...c, step: s.step(), bandwidth: s.bandwidth(), positions: dom.map((i) => s(i)) };
  }),
  point: bandCases.filter((c) => c.count > 0).map((c) => {
    const dom = [...Array(c.count).keys()]; const s = scalePoint().domain(dom).range(c.range);
    for (const [k, v] of Object.entries(c.opts)) if (k === "padding" || k === "align") s[k](v);
    return { ...c, step: s.step(), bandwidth: s.bandwidth(), positions: dom.map((i) => s(i)) };
  }),
  nice_ticks: [[0, 305, 5, true], [0, 505, 5, true], [0, 186, 5, true], [-50, 120, 5, true], [0, 1, 5, true], [0, 0.37, 5, true], [0, 7, 5, false], [3, 3, 5, true], [0, 0, 5, true], [2.4, 2.4, 5, false], [-8, -2, 4, true], [120, 480, 6, true], [305, 0, 5, true], [0, 12, 2, true], [0.0001, 0.0009, 5, true]]
    .flatMap(([a, b, c, dec]) => ["auto", "snap125"].map((mode) => ({ min: a, max: b, count: c, allow_decimals: dec, mode, ticks: getNiceTickValues([a, b], c, dec, mode) }))),
  fixed_domain: [[0, 400, 5, true], [0, 186, 5, true], [0, 100, 5, false], [100, 0, 5, true], [0.5, 9.5, 4, false], [3, 3, 5, true], [0, 7, 3, true]]
    .flatMap(([a, b, c, dec]) => ["auto", "snap125"].map((mode) => ({ min: a, max: b, count: c, allow_decimals: dec, mode, ticks: getTickValuesFixedDomain([a, b], c, dec, mode) }))),
};
writeFileSync(path.join(here, "../scale/oracle.json"), `${JSON.stringify(scalesOut, null, 1)}\n`);

// ---- shape --------------------------------------------------------------------------------------------------------------
const lineData = [[10, 80], [60, 20], [110, 55], [160, 140], [210, 60], [260, 61], [310, 15]];
const lineless = [[0, 0], [10, 10]];
const flat = [[0, 5], [40, 5], [80, 5], [120, 30]];
const pointSets = { zigzag: lineData, two: lineless, one: [[5, 5]], flat, empty: [], descending_x: [[100, 10], [60, 50], [20, 30]] };
const curveTypes = ["linear", "linearClosed", "monotone", "natural", "step", "stepBefore", "stepAfter", "basis", "basisClosed", "basisOpen", "bumpX", "bumpY"];
const pts = (a) => a.map(([x, y]) => ({ x, y }));
const curves = [];
for (const [name, set] of Object.entries(pointSets)) for (const type of curveTypes) curves.push({ set: name, points: set, type, d: getPath({ type, points: pts(set), layout: "horizontal" }) });
for (const type of ["monotone", "bump"]) curves.push({ set: "zigzag", points: lineData, type, layout: "vertical", d: getPath({ type, points: pts(lineData), layout: "vertical" }) });
const gap = [{ x: 0, y: 10 }, { x: 40, y: null }, { x: 80, y: 30 }, { x: 120, y: 5 }, { x: 160, y: 25 }];
const gapCases = [false, true].map((connectNulls) => ({ type: "monotone", connect_nulls: connectNulls, points: gap.map(({ x, y }) => [x, y]), d: getPath({ type: "monotone", points: gap, layout: "horizontal", connectNulls }) }));
const baseLine = lineData.map(([x]) => ({ x, y: 190 }));
const areas = ["linear", "monotone", "natural", "step", "basis"].map((type) => ({ type, points: lineData, base: baseLine.map(({ x, y }) => [x, y]), d: getPath({ type, points: pts(lineData), baseLine, layout: "horizontal" }) }))
  .concat(["linear", "monotone"].map((type) => ({ type, points: lineData, base_value: 190, d: getPath({ type, points: pts(lineData), baseLine: 190, layout: "horizontal" }) })))
  .concat([{ type: "linear", layout: "vertical", points: lineData, base_value: 20, d: getPath({ type: "linear", points: pts(lineData), baseLine: 20, layout: "vertical" }) }]);

const sectorD = (props) => { const m = renderToStaticMarkup(React.createElement(Sector, props)); const r = /d="([^"]*)"/.exec(m); return r ? r[1] : null; };
const sectorCases = [
  { cx: 160, cy: 100, innerRadius: 0, outerRadius: 80, startAngle: 0, endAngle: 90 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 90, endAngle: 250 },
  { cx: 160, cy: 100, innerRadius: 0, outerRadius: 80, startAngle: 0, endAngle: 360 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 0, endAngle: 360 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 300, endAngle: 20 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 90, endAngle: 0 },
  { cx: 160, cy: 100, innerRadius: 0, outerRadius: 80, startAngle: 10, endAngle: 100, cornerRadius: 8 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 10, endAngle: 100, cornerRadius: 8 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 10, endAngle: 100, cornerRadius: 8, cornerIsExternal: true },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 100, endAngle: 10, cornerRadius: 8 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 10, endAngle: 12, cornerRadius: 8 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 10, endAngle: 12, cornerRadius: 8, forceCornerRadius: true },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 10, endAngle: 100, cornerRadius: "50%" },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 10, endAngle: 100, cornerRadius: 100 },
  { cx: 160, cy: 100, innerRadius: 60, outerRadius: 40, startAngle: 10, endAngle: 100 },
  { cx: 160, cy: 100, innerRadius: 40, outerRadius: 80, startAngle: 30, endAngle: 30 },
  { cx: 160.5, cy: 99.25, innerRadius: 33.3, outerRadius: 71.7, startAngle: 12.34, endAngle: 211.11, cornerRadius: 5 },
];
const sectors = sectorCases.map((props) => ({ props, d: sectorD(props) }));

const pieData = [{ name: "a", value: 275 }, { name: "b", value: 200 }, { name: "c", value: 0 }, { name: "d", value: 187 }, { name: "e", value: 173 }];
const pieSettingsBase = { cx: "50%", cy: "50%", innerRadius: 0, outerRadius: "80%", startAngle: 0, endAngle: 360, minAngle: 0, paddingAngle: 0, cornerRadius: 0, dataKey: "value", nameKey: "name", tooltipType: undefined, fill: "#808080", presentationProps: {}, id: "p" };
const offset = { top: 5, right: 5, bottom: 5, left: 5, width: 310, height: 190 };
const pies = [
  { start_angle: 0, end_angle: 360, pad_angle: 0, min_angle: 0 },
  { start_angle: 0, end_angle: 360, pad_angle: 5, min_angle: 0 },
  { start_angle: 90, end_angle: -270, pad_angle: 3, min_angle: 4 },
  { start_angle: 0, end_angle: 180, pad_angle: 5, min_angle: 0 },
  { start_angle: 180, end_angle: 0, pad_angle: 2, min_angle: 10 },
].map((o) => {
  const out = computePieSectors({ pieSettings: { ...pieSettingsBase, startAngle: o.start_angle, endAngle: o.end_angle, paddingAngle: o.pad_angle, minAngle: o.min_angle }, displayedData: pieData, cells: undefined, offset });
  return { ...o, values: pieData.map((d) => d.value), sectors: out.map((s) => ({ start_angle: s.startAngle, end_angle: s.endAngle, mid_angle: s.midAngle, percent: s.percent })) };
});

const stackData = [{ a: 10, b: 20, c: 5 }, { a: 0, b: 15 }, { a: 30, b: -5, c: 10 }, { a: 5, b: 5, c: 5 }];
const stacks = ["none", "expand"].map((offsetType) => ({ offset: offsetType, keys: ["a", "b", "c"], data: stackData, series: getStackedData(stackData, ["a", "b", "c"], offsetType).map((s) => s.map(([lo, hi]) => [lo, hi])) }));

writeFileSync(path.join(here, "oracle.json"), `${JSON.stringify({ curves, gaps: gapCases, areas, sectors, pies, stacks }, null, 1)}\n`);
console.log("wrote scale/oracle.json and shape/oracle.json");
