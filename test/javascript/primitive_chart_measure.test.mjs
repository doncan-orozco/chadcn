import { assert, primitiveTest } from "./primitives_support.mjs";

// chart_measure (dev/port/specs/chart.md, "Behavior", "Resize and re-measure", Measure; item #108): the text metrics chadcn--chart
// measures the way recharts does (util/DOMUtils.js measureTextWithDOM: a white-space: pre span under body) and whether they ask for a
// re-layout. The request and the swap are the controller's, covered in chart_remeasure.test.mjs.

// A chart as the server draws it: tick labels in svg text at the tick font, a legend wrapper of a known height.
const CHART = `<div data-slot="chart" style="font-size: 12px">
  <svg><g class="recharts-cartesian-axis-tick"><text class="recharts-cartesian-axis-tick-value">Jan</text></g>
  <g class="recharts-cartesian-axis-tick"><text class="recharts-cartesian-axis-tick-value">February</text></g></svg>
  <div class="recharts-legend-wrapper" style="height: 26.5px"></div>
</div>`;
const CSS = "body { font: 12px/14px monospace; margin: 0 }";
const SERVED = { textHeight: 16, textCharWidth: 0.6, legendHeight: 28 };

primitiveTest("chart_measure: measureTextMetrics measures a line of tick text, the average glyph width and the legend box", async (page) => {
  const result = await page.evaluate(async (served) => {
    const { measureTextMetrics } = await import("chadcn/primitives/chart_measure");
    const chart = document.querySelector("[data-slot=chart]");
    // the reference: the labels in a span under body, at the font size of the first label
    const span = document.body.appendChild(document.createElement("span"));
    Object.assign(span.style, { position: "absolute", whiteSpace: "pre", fontSize: "12px" });
    const rects = ["Jan", "February"].map((text) => { span.textContent = text; return span.getBoundingClientRect(); });
    span.remove();
    const expected = { textHeight: rects[0].height, textCharWidth: Math.round(((rects[0].width + rects[1].width) / 11 / 12) * 1e4) / 1e4 };
    return { measured: measureTextMetrics(chart, served), expected, spans: document.body.querySelectorAll(":scope > span").length };
  }, SERVED);

  assert.equal(result.measured.textHeight, result.expected.textHeight);
  assert.equal(result.measured.textCharWidth, result.expected.textCharWidth);
  assert.equal(result.measured.textHeight, 14, "the line height of the page, not the 16 px the server assumes");
  assert.ok(Math.abs(result.measured.textCharWidth - 0.6) < 0.01, `monospace is about 0.6 em wide (got ${result.measured.textCharWidth})`);
  assert.equal(result.measured.legendHeight, 26.5);
  assert.equal(result.spans, 0, "the measuring span is removed again");
}, { html: CHART, css: CSS });

primitiveTest("chart_measure: without tick labels the text metrics are the served ones, without a legend there is no legendHeight", async (page) => {
  const result = await page.evaluate(async (served) => {
    const { measureTextMetrics } = await import("chadcn/primitives/chart_measure");
    const chart = document.querySelector("[data-slot=chart]");
    for (const node of chart.querySelectorAll(".recharts-cartesian-axis-tick-value")) node.remove();
    const withLegend = measureTextMetrics(chart, served);
    chart.querySelector(".recharts-legend-wrapper").remove();
    return [withLegend, measureTextMetrics(chart, served), measureTextMetrics(chart, { textHeight: 18, textCharWidth: 0.6 })];
  }, SERVED);

  assert.deepEqual(result, [
    { textHeight: 16, textCharWidth: 0.6, legendHeight: 26.5 },
    { textHeight: 16, textCharWidth: 0.6 },
    { textHeight: 18, textCharWidth: 0.6 },
  ]);
}, { html: CHART, css: CSS });

primitiveTest("chart_measure: metricsDiffer compares the measured metrics with the served ones to 4 decimals", async (page) => {
  const result = await page.evaluate(async () => {
    const { metricsDiffer } = await import("chadcn/primitives/chart_measure");
    const served = { textHeight: 18, textCharWidth: 0.5622, legendHeight: 28 };
    return [
      metricsDiffer({ textHeight: 18, textCharWidth: 0.5622, legendHeight: 28 }, served),
      metricsDiffer({ textHeight: 18.00001, textCharWidth: 0.56220004, legendHeight: 28 }, served),
      metricsDiffer({ textHeight: 14, textCharWidth: 0.5622, legendHeight: 28 }, served),
      metricsDiffer({ textHeight: 18, textCharWidth: 0.5599, legendHeight: 28 }, served),
      metricsDiffer({ textHeight: 18, textCharWidth: 0.5622, legendHeight: 26 }, served),
      metricsDiffer({ textHeight: 18, textCharWidth: 0.5622 }, served),
      metricsDiffer({ textHeight: 18, textCharWidth: 0.5622, legendHeight: 26 }, { textHeight: 18, textCharWidth: 0.5622 }),
      metricsDiffer({ textHeight: 18, textCharWidth: 0.5622 }, {}),
    ];
  });

  assert.deepEqual(result, [false, false, true, true, true, false, true, true]);
});

primitiveTest("chart_measure: remeasureNeeded asks once per size: a chart re-laid out for its metrics at this size never asks again", async (page) => {
  const result = await page.evaluate(async () => {
    const { remeasureNeeded } = await import("chadcn/primitives/chart_measure");
    const served = { textHeight: 18, textCharWidth: 0.6 };
    const measured = { textHeight: 14, textCharWidth: 0.5622 };
    const size = { width: 320, height: 200 };
    return [
      remeasureNeeded({ measured, served, size, measuredAt: undefined }),
      remeasureNeeded({ measured: served, served, size, measuredAt: undefined }),
      remeasureNeeded({ measured, served, size, measuredAt: { width: 320, height: 200 } }),
      remeasureNeeded({ measured, served, size, measuredAt: { width: 480, height: 300 } }),
      remeasureNeeded({ measured, served, size: { width: 0, height: 200 }, measuredAt: undefined }),
      remeasureNeeded({ measured, served, size: { width: NaN, height: 200 }, measuredAt: undefined }),
    ];
  });

  assert.deepEqual(result, [true, false, false, true, false, false]);
});
