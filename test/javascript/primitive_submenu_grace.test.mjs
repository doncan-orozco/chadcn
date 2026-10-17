import { assert, primitiveTest, useFakeTimers } from "./primitives_support.mjs";

// trigger bottom edge y=130; content below it; sub is a right-side submenu.
const html = `
  <div id="menu" style="position:fixed;left:0;top:0;width:200px;height:300px">
    <div id="trigger" style="position:fixed;left:100px;top:100px;width:80px;height:30px"></div>
  </div>
  <div id="content" style="position:fixed;left:100px;top:200px;width:200px;height:100px"></div>
  <div id="sub" data-side="right" style="position:fixed;left:200px;top:100px;width:200px;height:100px"></div>`;

primitiveTest("submenu_grace: geometry helpers (polygon test, exit side, padded points, rect points)", async (page) => {
  const result = await page.evaluate(async () => {
    const m = await import("shadcn/primitives/submenu_grace");
    const square = [{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }, { x: 0, y: 10 }];
    const rect = { top: 0, right: 100, bottom: 50, left: 0 };
    return {
      constants: [m.GRACE_TIMEOUT, m.GRACE_PADDING],
      inside: m.isPointInPolygon({ x: 5, y: 5 }, square), outside: m.isPointInPolygon({ x: 11, y: 5 }, square),
      graceEvent: m.isPointerInGraceArea({ clientX: 5, clientY: 5 }, square), graceNone: m.isPointerInGraceArea({ clientX: 5, clientY: 5 }, null),
      sides: ["left", "right", "top", "bottom"].map((s) => m.getExitSideFromRect(({ left: { x: -1, y: 25 }, right: { x: 101, y: 25 }, top: { x: 50, y: -1 }, bottom: { x: 50, y: 51 } })[s], rect)),
      bottom: m.getPaddedExitPoints({ x: 10, y: 20 }, "bottom", 5), left: m.getPaddedExitPoints({ x: 10, y: 20 }, "left"),
      points: m.getPointsFromRect(rect),
    };
  });
  assert.deepEqual(result.constants, [300, 5]);
  assert.deepEqual([result.inside, result.outside, result.graceEvent, result.graceNone], [true, false, true, false]);
  assert.deepEqual(result.sides, ["left", "right", "top", "bottom"]);
  assert.deepEqual(result.bottom, [{ x: 5, y: 15 }, { x: 15, y: 15 }]);
  assert.deepEqual(result.left, [{ x: 15, y: 15 }, { x: 15, y: 25 }]);
  assert.deepEqual(result.points, [{ x: 0, y: 0 }, { x: 100, y: 0 }, { x: 100, y: 50 }, { x: 0, y: 50 }]);
}, { html });

primitiveTest("submenu_grace: getHull returns the convex hull and tolerates degenerate input", async (page) => {
  const result = await page.evaluate(async () => {
    const { getHull } = await import("shadcn/primitives/submenu_grace");
    const p = (x, y) => ({ x, y });
    return {
      hull: getHull([p(0, 0), p(10, 0), p(10, 10), p(0, 10), p(5, 5)]).map(({ x, y }) => `${x},${y}`).sort(),
      single: getHull([p(1, 1)]), empty: getHull([]), same: getHull([p(2, 2), p(2, 2)]),
    };
  });
  assert.deepEqual(result.hull, ["0,0", "0,10", "10,0", "10,10"]);
  assert.deepEqual(result.single, [{ x: 1, y: 1 }]);
  assert.deepEqual(result.empty, []);
  assert.deepEqual(result.same, [{ x: 2, y: 2 }]);
}, { html });

primitiveTest("submenu_grace: a pointer heading into the sub content is within the grace area until the timeout; leaving without sub content clears it", async (page) => {
  await useFakeTimers(page);
  const result = await page.evaluate(async () => {
    const { submenuGrace } = await import("shadcn/primitives/submenu_grace");
    const grace = submenuGrace(document.getElementById("menu"), { timeout: 300 });
    const sub = document.getElementById("sub");
    const at = (x, y) => ({ clientX: x, clientY: y });
    const heading = grace.subTriggerLeave(at(190, 150), sub);
    const inArea = grace.isPointerMovingToSubmenu(at(300, 150));
    const outsideArea = grace.isPointerMovingToSubmenu(at(100, 150));
    window.__clock.advance(300);
    const expired = grace.isPointerMovingToSubmenu(at(300, 150));
    grace.subTriggerLeave(at(190, 150), sub);
    const nothing = grace.subTriggerLeave(at(190, 150), null);
    return { heading, inArea, outsideArea, expired, nothing, afterNull: grace.isPointerMovingToSubmenu(at(300, 150)) };
  });
  assert.deepEqual(result, { heading: true, inArea: true, outsideArea: false, expired: false, nothing: false, afterNull: false });
}, { html });

primitiveTest("submenu_grace: pointer direction is tracked for mouse moves over the content only; release() stops tracking and clears the intent", async (page) => {
  await useFakeTimers(page);
  const result = await page.evaluate(async () => {
    const { submenuGrace } = await import("shadcn/primitives/submenu_grace");
    const menu = document.getElementById("menu");
    const grace = submenuGrace(menu);
    const sub = document.getElementById("sub");
    const move = (x, pointerType = "mouse") => document.getElementById("trigger").dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX: x, clientY: 150, pointerType }));
    move(120); // right (default right) then left
    move(50);
    const leftSide = grace.subTriggerLeave({ clientX: 190, clientY: 150 }, sub); // sub is on the right; the pointer moves left
    move(60, "touch");
    move(150);
    const rightAgain = grace.isPointerMovingToSubmenu({ clientX: 300, clientY: 150 });
    grace.release();
    const pending = window.__clock.pending();
    // Note: the post-release `afterRelease: true` below is incidental to the accepted release behavior, not a contract.
    const immediately = grace.isPointerMovingToSubmenu({ clientX: 300, clientY: 150 });
    move(40);
    grace.subTriggerLeave({ clientX: 190, clientY: 150 }, sub);
    return { leftSide, rightAgain, pending, immediately, afterRelease: grace.isPointerMovingToSubmenu({ clientX: 300, clientY: 150 }) };
  });
  assert.deepEqual(result, { leftSide: false, rightAgain: true, pending: 0, immediately: false, afterRelease: true });
}, { html });

primitiveTest("submenu_grace: hoverGrace keeps the pointer in transit inside the hull and closes when it leaves it", async (page) => {
  await useFakeTimers(page);
  const result = await page.evaluate(async () => {
    const { hoverGrace } = await import("shadcn/primitives/submenu_grace");
    const log = [];
    const grace = hoverGrace(document.getElementById("trigger"), document.getElementById("content"), {
      onInTransitChange: (value) => log.push(`transit:${value}`), onClose: () => log.push("close"),
    });
    const leave = (x, y) => document.getElementById("trigger").dispatchEvent(new PointerEvent("pointerleave", { clientX: x, clientY: y }));
    const move = (x, y) => document.body.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX: x, clientY: y }));
    leave(140, 129);
    move(700, 50); // outside the hull, but before the zero timeout: the document listener is not attached yet
    const stillTransit = [...log];
    window.__clock.advance(0);
    move(700, 50); // now tracked: outside the hull closes
    const result = { stillTransit, log: [...log] };
    grace.release();
    return result;
  });
  assert.deepEqual(result.stillTransit, ["transit:true"]);
  assert.deepEqual(result.log, ["transit:true", "transit:false", "close"]);
}, { html });

primitiveTest("submenu_grace: hoverGrace ends the transit without closing when the pointer reaches the content; release() detaches everything", async (page) => {
  await useFakeTimers(page);
  const result = await page.evaluate(async () => {
    const { hoverGrace } = await import("shadcn/primitives/submenu_grace");
    const log = [];
    const trigger = document.getElementById("trigger");
    const content = document.getElementById("content");
    const grace = hoverGrace(trigger, content, { onInTransitChange: (v) => log.push(`transit:${v}`), onClose: () => log.push("close") });
    trigger.dispatchEvent(new PointerEvent("pointerleave", { clientX: 140, clientY: 129 }));
    window.__clock.advance(0);
    content.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX: 150, clientY: 250 }));
    const reached = [...log];
    trigger.dispatchEvent(new PointerEvent("pointerleave", { clientX: 140, clientY: 129 }));
    grace.release();
    const released = [...log];
    trigger.dispatchEvent(new PointerEvent("pointerleave", { clientX: 140, clientY: 129 }));
    window.__clock.advance(10);
    document.body.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX: 700, clientY: 50 }));
    return { reached, released, final: log, pending: window.__clock.pending() };
  });
  assert.deepEqual(result.reached, ["transit:true", "transit:false"]);
  assert.deepEqual(result.released, ["transit:true", "transit:false", "transit:true", "transit:false"]);
  assert.deepEqual(result.final, result.released, "no events after release");
  assert.equal(result.pending, 0);
}, { html });
