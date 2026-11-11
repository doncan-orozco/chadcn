import { assert, primitiveTest } from "./primitives_support.mjs";

// chart_relayout (dev/port/specs/chart.md, "Behavior", "Resize and re-measure"): the pure half of the re-layout of chadcn--chart
// (sizes, the request URL, the chart in the response) and the two DOM helpers it composes (the settled-size observer, the interim
// scaling). The request, the swap and the events are the controller's, covered in chart.test.mjs.

primitiveTest("chart_relayout: roundedSize rounds to whole pixels", async (page) => {
  const result = await page.evaluate(async () => {
    const { roundedSize } = await import("chadcn/primitives/chart_relayout");
    return [roundedSize({ width: 639.5, height: 399.49 }), roundedSize({ width: 0.2, height: 4096.4 })];
  });
  assert.deepEqual(result, [{ width: 640, height: 399 }, { width: 0, height: 4096 }]);
});

primitiveTest("chart_relayout: relayoutNeeded only for a different size between 1 and 4096 px", async (page) => {
  const result = await page.evaluate(async () => {
    const { relayoutNeeded, RELAYOUT_MAX_SIZE } = await import("chadcn/primitives/chart_relayout");
    const laidOut = { width: 320, height: 200 };
    return [
      RELAYOUT_MAX_SIZE,
      relayoutNeeded({ width: 320, height: 200 }, laidOut),
      relayoutNeeded({ width: 640, height: 200 }, laidOut),
      relayoutNeeded({ width: 320, height: 201 }, laidOut),
      relayoutNeeded({ width: 0, height: 200 }, laidOut),
      relayoutNeeded({ width: 4096, height: 4096 }, laidOut),
      relayoutNeeded({ width: 4097, height: 400 }, laidOut),
      relayoutNeeded({ width: 640, height: 400 }, {}),
    ];
  });
  assert.deepEqual(result, [4096, false, true, true, false, true, false, true]);
});

primitiveTest("chart_relayout: relayoutRequestUrl adds the chart parameters to the URL's own query, same origin only", async (page) => {
  const result = await page.evaluate(async () => {
    const { relayoutRequestUrl } = await import("chadcn/primitives/chart_relayout");
    const size = { width: 640, height: 400 };
    const metrics = { textHeight: 16, textCharWidth: 0.6 };
    const href = (url) => url?.href ?? null;
    return [
      href(relayoutRequestUrl("/reports/chart?range=30d#top", { id: "sales", size, metrics })),
      href(relayoutRequestUrl("/r?chart%5Bwidth%5D=1", { id: "sales", size, metrics: { ...metrics, legendHeight: 28 } })),
      href(relayoutRequestUrl("http://primitives.test/r", { id: "sales", size, metrics })),
      href(relayoutRequestUrl("https://evil.test/r", { id: "sales", size, metrics })),
      href(relayoutRequestUrl("//evil.test/r", { id: "sales", size, metrics })),
      href(relayoutRequestUrl("javascript:alert(1)", { id: "sales", size, metrics })),
      href(relayoutRequestUrl("http://[bad", { id: "sales", size, metrics })),
    ];
  });
  assert.deepEqual(result, [
    "http://primitives.test/reports/chart?range=30d&chart%5Bid%5D=sales&chart%5Bwidth%5D=640&chart%5Bheight%5D=400&chart%5Btext_height%5D=16&chart%5Btext_char_width%5D=0.6",
    "http://primitives.test/r?chart%5Bwidth%5D=640&chart%5Bid%5D=sales&chart%5Bheight%5D=400&chart%5Btext_height%5D=16&chart%5Btext_char_width%5D=0.6&chart%5Blegend_height%5D=28",
    "http://primitives.test/r?chart%5Bid%5D=sales&chart%5Bwidth%5D=640&chart%5Bheight%5D=400&chart%5Btext_height%5D=16&chart%5Btext_char_width%5D=0.6",
    null, null, null, null,
  ]);
});

primitiveTest("chart_relayout: chartInResponse finds the chart of that name in an inert document, or nothing", async (page) => {
  const result = await page.evaluate(async () => {
    const { chartInResponse } = await import("chadcn/primitives/chart_relayout");
    window.ran = false;
    const html = `<html><body><img src=x onerror="window.ran = true"><script>window.ran = true</script>
      <div data-slot="chart" data-chart="chart-other"></div>
      <div data-slot="card"><div data-slot="chart" data-chart="chart-sales" id="hit"><svg class="recharts-surface"></svg></div></div></body></html>`;
    const found = chartInResponse(html, "chart-sales");
    await new Promise((resolve) => setTimeout(resolve, 50));
    return {
      id: found?.id,
      inert: found?.ownerDocument !== document,
      missing: chartInResponse(html, "chart-none"),
      quoted: chartInResponse(html, 'chart-sales"]'),
      empty: chartInResponse("", "chart-sales"),
      ran: window.ran,
    };
  });
  assert.deepEqual(result, { id: "hit", inert: true, missing: null, quoted: null, empty: null, ran: false });
});

primitiveTest("chart_relayout: laidOutAt reads the dimension value of a chart", async (page) => {
  const result = await page.evaluate(async () => {
    const { laidOutAt } = await import("chadcn/primitives/chart_relayout");
    const chart = (value) => {
      const element = document.createElement("div");
      if (value !== undefined) element.setAttribute("data-chadcn--chart-dimension-value", value);
      return element;
    };
    const size = { width: 640, height: 400 };
    const attribute = "data-chadcn--chart-dimension-value";
    return [
      laidOutAt(chart('{"width":640,"height":400}'), size, attribute),
      laidOutAt(chart('{"width":320,"height":200}'), size, attribute),
      laidOutAt(chart("not json"), size, attribute),
      laidOutAt(chart(), size, attribute),
    ];
  });
  assert.deepEqual(result, [true, false, false, false]);
});

primitiveTest("chart_relayout: observeSettledSize reports the content box once it has been still for the delay, and stops on disconnect", async (page) => {
  const result = await page.evaluate(async () => {
    const { observeSettledSize } = await import("chadcn/primitives/chart_relayout");
    const element = document.createElement("div");
    element.style.cssText = "width: 320px; height: 200px; padding: 10px; box-sizing: content-box";
    document.body.append(element);
    const reports = [];
    const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const observer = observeSettledSize(element, (size) => reports.push(size), { delay: 80 });
    await wait(150);
    for (const width of [400, 500.4, 640.6]) {
      element.style.width = `${width}px`;
      await wait(20);
    }
    await wait(150);
    element.style.width = "700px";
    await wait(20);
    observer.disconnect();
    await wait(150);
    element.style.width = "800px";
    await wait(150);
    return reports;
  });
  assert.deepEqual(result, [{ width: 320, height: 200 }, { width: 641, height: 200 }]);
});

primitiveTest("chart_relayout: scaleToBox sets the wrapper and the inner div of the shell to the box, and restore puts them back", async (page) => {
  const result = await page.evaluate(async () => {
    const { scaleToBox } = await import("chadcn/primitives/chart_relayout");
    const chart = document.createElement("div");
    chart.innerHTML = `<div class="recharts-responsive-container" style="width: 100%; height: 100%; min-width: 0px;"><div style="width: 0px; height: 0px; overflow: visible;"><div class="recharts-wrapper" style="position: relative; cursor: default; width: 320px; height: 200px;"></div></div></div>`;
    const wrapper = chart.querySelector(".recharts-wrapper");
    const styles = () => [wrapper.parentElement.getAttribute("style"), wrapper.getAttribute("style")];
    const before = styles();
    const restore = scaleToBox(chart);
    const scaled = styles();
    restore();
    restore();
    return { before, scaled, after: styles(), none: typeof scaleToBox(document.createElement("div")) };
  });
  assert.deepEqual(result.scaled, ["width: 100%; height: 100%; overflow: visible;", "position: relative; cursor: default; width: 100%; height: 100%;"]);
  assert.deepEqual(result.after, result.before);
  assert.equal(result.none, "function");
});
