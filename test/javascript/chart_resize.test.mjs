// chadcn--chart re-layout (dev/port/specs/chart.md, "Behavior", "Resize and re-measure"; item #107): a chart with relayout_url:
// follows its container, and the swapped-in chart matches recharts resized in the browser at the same width, under G2's rules.
// The lifecycle (debounce, abort, errors, disconnect, Turbo) is chart_resize_lifecycle.test.mjs; shared support: chart_resize_support.mjs.
import test from "node:test";
import { assert } from "./support.mjs";
import {
  CHART, chartValue, RESIZE_OBSERVE, answerRelayout, withResizable, resizeTo, relayoutEvents, waitForEvents, chartNodes, nodeDifferences, rechartsAt,
} from "./chart_resize_support.mjs";

test("chart: a chart with relayout_url: follows its container from 320 to 480 to 640 px and matches recharts at each width", () => withResizable("bar", async (page, enable) => {
  const requests = await answerRelayout(page, "bar");
  await enable();

  await resizeTo(page, 480);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 480, height: 300 }]);
  assert.deepEqual(nodeDifferences(await rechartsAt("bar", 480), await chartNodes(page, RESIZE_OBSERVE.bar)), []);

  await resizeTo(page, 640);
  await waitForEvents(page, 2);
  assert.deepEqual((await relayoutEvents(page))[1], { name: "relayout", width: 640, height: 400 });
  assert.deepEqual(nodeDifferences(await rechartsAt("bar", 640), await chartNodes(page, RESIZE_OBSERVE.bar)), []);
  assert.equal(await page.locator(CHART).count(), 1, "the chart was replaced, not added");
  assert.equal(await chartValue(page, "dimension"), JSON.stringify({ width: 640, height: 400 }));

  assert.equal(requests.length, 2, "the first request ever was for the 480 box: none at the size the server laid out");
  assert.deepEqual(requests[0], {
    source: "test", "chart[id]": "resize-bar", "chart[width]": "480", "chart[height]": "300", "chart[text_height]": "18", "chart[text_char_width]": "0.6",
  });
}));

test("chart: a pie with relayout_url: follows its container to 640 px and matches recharts", () => withResizable("pie", async (page, enable) => {
  await answerRelayout(page, "pie");
  await enable();
  await resizeTo(page, 640);
  await waitForEvents(page, 1);
  assert.deepEqual(await relayoutEvents(page), [{ name: "relayout", width: 640, height: 400 }]);
  assert.deepEqual(nodeDifferences(await rechartsAt("pie", 640), await chartNodes(page, RESIZE_OBSERVE.pie)), []);
}));
