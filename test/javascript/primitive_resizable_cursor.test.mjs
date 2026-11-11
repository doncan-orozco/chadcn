import { assert, primitiveTest } from "./primitives_support.mjs";

// The resize cursor of the resizable group, called directly: interaction state, limit flags and orientations in, a cursor out.

const axis = (orientation, disableCursor = false) => ({ orientation, mutableState: { disableCursor } });
const axes = { horizontal: axis("horizontal"), vertical: axis("vertical"), off: axis("horizontal", true) };

primitiveTest("resizable_cursor: hover picks the Chromium axis cursor, move for both axes", async (page) => {
  const cursors = await page.evaluate(async (fixtures) => {
    const { cursorFor } = await import("chadcn/primitives/resizable_cursor");
    const hover = (list) => cursorFor({ cursorFlags: 0, axes: list, state: "hover", chromium: true });
    return [hover([fixtures.horizontal]), hover([fixtures.vertical]), hover([fixtures.horizontal, fixtures.vertical])];
  }, axes);
  assert.deepEqual(cursors, ["ew-resize", "ns-resize", "move"]);
});

primitiveTest("resizable_cursor: hover picks the col/row cursor of the other browsers, grab for both axes", async (page) => {
  const cursors = await page.evaluate(async (fixtures) => {
    const { cursorFor } = await import("chadcn/primitives/resizable_cursor");
    const hover = (list) => cursorFor({ cursorFlags: 0, axes: list, state: "hover", chromium: false });
    return [hover([fixtures.horizontal]), hover([fixtures.vertical]), hover([fixtures.horizontal, fixtures.vertical])];
  }, axes);
  assert.deepEqual(cursors, ["col-resize", "row-resize", "grab"]);
});

primitiveTest("resizable_cursor: no cursor when the groups disable it or the interaction is inactive", async (page) => {
  const cursors = await page.evaluate(async (fixtures) => {
    const { cursorFor } = await import("chadcn/primitives/resizable_cursor");
    return {
      disabled: cursorFor({ cursorFlags: 0, axes: [fixtures.off], state: "hover", chromium: true }) ?? null,
      inactive: cursorFor({ cursorFlags: 0, axes: [fixtures.horizontal], state: "inactive", chromium: true }) ?? null,
    };
  }, axes);
  assert.deepEqual(cursors, { disabled: null, inactive: null });
});

primitiveTest("resizable_cursor: an active drag at a limit points back only (Chromium)", async (page) => {
  const cursors = await page.evaluate(async (horizontal) => {
    const { CURSOR_DOWN, CURSOR_LEFT, CURSOR_RIGHT, CURSOR_UP, cursorFor } = await import("chadcn/primitives/resizable_cursor");
    const active = (cursorFlags, chromium = true) => cursorFor({ cursorFlags, axes: [horizontal], state: "active", chromium });
    return {
      left: active(CURSOR_LEFT), right: active(CURSOR_RIGHT), leftUp: active(CURSOR_LEFT | CURSOR_UP), rightDown: active(CURSOR_RIGHT | CURSOR_DOWN),
      leftDown: active(CURSOR_LEFT | CURSOR_DOWN), rightUp: active(CURSOR_RIGHT | CURSOR_UP), up: active(CURSOR_UP), down: active(CURSOR_DOWN),
      otherBrowser: active(CURSOR_LEFT, false),
    };
  }, axes.horizontal);
  assert.deepEqual(cursors, {
    left: "e-resize", right: "w-resize", leftUp: "se-resize", rightDown: "nw-resize", leftDown: "ne-resize", rightUp: "sw-resize",
    up: "s-resize", down: "n-resize", otherBrowser: "col-resize",
  });
});

primitiveTest("resizable_cursor: an active drag that is not at a limit keeps the plain axis cursor", async (page) => {
  const cursor = await page.evaluate(async (horizontal) => {
    const { cursorFor } = await import("chadcn/primitives/resizable_cursor");
    return cursorFor({ cursorFlags: 0, axes: [horizontal], state: "active", chromium: true });
  }, axes.horizontal);
  assert.equal(cursor, "ew-resize");
});

primitiveTest("resizable_cursor: limitFlag points at the side the drag could not move to", async (page) => {
  const flags = await page.evaluate(async () => {
    const { limitFlag } = await import("chadcn/primitives/resizable_cursor");
    return {
      left: limitFlag({ orientation: "horizontal", delta: -1 }), right: limitFlag({ orientation: "horizontal", delta: 1 }),
      up: limitFlag({ orientation: "vertical", delta: -1 }), down: limitFlag({ orientation: "vertical", delta: 1 }),
    };
  });
  assert.deepEqual(flags, { left: 1, right: 2, up: 4, down: 8 });
});

primitiveTest("resizable_cursor: limitFlag of an unknown orientation is 0", async (page) => {
  const flag = await page.evaluate(async () => {
    const { limitFlag } = await import("chadcn/primitives/resizable_cursor");
    return limitFlag({ orientation: "diagonal", delta: 1 });
  });
  assert.equal(flag, 0);
});

primitiveTest("resizable_cursor: nextCursorFlags keeps the previous flags of an axis the pointer did not move along", async (page) => {
  const flags = await page.evaluate(async () => {
    const { CURSOR_DOWN, CURSOR_LEFT, CURSOR_RIGHT, CURSOR_UP, nextCursorFlags } = await import("chadcn/primitives/resizable_cursor");
    const next = (movementX, movementY) => nextCursorFlags({
      flags: CURSOR_RIGHT | CURSOR_DOWN, prevCursorFlags: CURSOR_LEFT | CURSOR_UP, movementX, movementY
    });
    return { none: next(0, 0), both: next(3, 2), onlyX: next(3, 0), onlyY: next(0, 2) };
  });
  assert.equal(flags.none, 5);
  assert.equal(flags.both, 10);
  assert.equal(flags.onlyX, 6);
  assert.equal(flags.onlyY, 9);
});

primitiveTest("resizable_cursor: cursorRule overrides the cursor of every element", async (page) => {
  const rule = await page.evaluate(async () => {
    const { cursorRule } = await import("chadcn/primitives/resizable_cursor");
    return cursorRule("ew-resize");
  });
  assert.equal(rule, "*, *:hover {cursor: ew-resize !important; }");
});
