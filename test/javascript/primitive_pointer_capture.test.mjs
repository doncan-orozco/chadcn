import { assert, primitiveTest } from "./primitives_support.mjs";

const html = `<div id="root" style="position:fixed;left:100px;top:100px;width:200px;height:100px"><span id="thumb" style="display:block;width:50px;height:50px">t</span></div>
  <div id="far" style="position:fixed;left:500px;top:400px;width:50px;height:50px"></div>`;

const start = (page, extra = "") => page.evaluate(async (extra) => {
  const { pointerCapture } = await import("chadcn/primitives/pointer_capture");
  window.__log = [];
  const log = (name) => (event) => window.__log.push([name, event.type, event.target.id, event.target.hasPointerCapture(event.pointerId)]);
  const options = new Function("log", `return { onStart: log("start"), onMove: log("move"), onEnd: log("end"), ${extra} }`)(log);
  window.__drag = pointerCapture(document.getElementById("root"), options);
}, extra);
const log = (page) => page.evaluate(() => window.__log);

primitiveTest("pointer_capture: pointerdown captures the target; moves and up are reported while captured, and up releases the capture first", async (page) => {
  await start(page);
  await page.mouse.move(120, 120);
  await page.mouse.down();
  await page.mouse.move(520, 420); // far outside the root: the capture keeps events flowing
  await page.mouse.up();
  await page.mouse.move(130, 130);
  const entries = await log(page);
  assert.deepEqual(entries.map(([name]) => name), ["start", "move", "end"]);
  assert.deepEqual(entries.map(([, , target]) => target), ["thumb", "thumb", "thumb"]);
  assert.deepEqual(entries.map(([, , , captured]) => captured), [true, true, false], "capture is released before onEnd");
}, { html });

primitiveTest("pointer_capture: pointerdown is default-prevented and filter() can ignore it entirely", async (page) => {
  await start(page, "filter: (event) => event.button === 0");
  await page.evaluate(() => { window.__prevented = []; document.addEventListener("pointerdown", (e) => queueMicrotask(() => window.__prevented.push(e.defaultPrevented))) });
  await page.mouse.move(120, 120);
  await page.mouse.down({ button: "right" });
  await page.mouse.up({ button: "right" });
  assert.deepEqual(await log(page), []);
  await page.mouse.down();
  await page.mouse.up();
  assert.deepEqual((await log(page)).map(([name]) => name), ["start", "end"]);
  assert.deepEqual(await page.evaluate(() => window.__prevented), [false, true]);
}, { html });

primitiveTest("pointer_capture: moves without a prior pointerdown are ignored; isCapturing reflects the capture", async (page) => {
  await start(page);
  await page.evaluate(() => {
    window.__capturing = [];
    document.getElementById("root").addEventListener("pointermove", (event) => window.__capturing.push(window.__drag.isCapturing(event)));
  });
  await page.mouse.move(120, 120);
  await page.mouse.move(150, 150);
  assert.deepEqual(await log(page), []);
  await page.mouse.down();
  await page.mouse.move(160, 160);
  await page.mouse.up();
  assert.deepEqual(await page.evaluate(() => window.__capturing), [false, false, true]);
}, { html });

primitiveTest("pointer_capture: onCancel is optional and only fires on pointercancel", async (page) => {
  await start(page, 'onCancel: (event) => window.__log.push(["cancel", event.type])');
  await page.evaluate(() => document.getElementById("thumb").dispatchEvent(new PointerEvent("pointercancel", { bubbles: true })));
  assert.deepEqual(await log(page), [["cancel", "pointercancel"]]);
  await page.evaluate(() => window.__drag.release());
  await page.evaluate(() => document.getElementById("thumb").dispatchEvent(new PointerEvent("pointercancel", { bubbles: true })));
  assert.equal((await log(page)).length, 1);
}, { html });

primitiveTest("pointer_capture: a missing onCancel is harmless", async (page) => {
  await start(page);
  await page.evaluate(() => document.getElementById("thumb").dispatchEvent(new PointerEvent("pointercancel", { bubbles: true })));
  assert.deepEqual(await log(page), []);
}, { html });

primitiveTest("pointer_capture: release() removes every listener", async (page) => {
  await start(page);
  await page.evaluate(() => window.__drag.release());
  await page.mouse.move(120, 120);
  await page.mouse.down();
  await page.mouse.move(150, 150);
  await page.mouse.up();
  assert.deepEqual(await log(page), []);
}, { html });

primitiveTest("pointer_capture: release() mid-drag stops onMove and onEnd", async (page) => {
  await start(page);
  await page.mouse.move(120, 120);
  await page.mouse.down();
  await page.mouse.move(150, 150);
  await page.evaluate(() => window.__drag.release());
  await page.mouse.move(520, 420);
  await page.mouse.up();
  assert.deepEqual((await log(page)).map(([name]) => name), ["start", "move"]);
}, { html });
