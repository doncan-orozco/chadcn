import { assert, primitiveTest } from "./primitives_support.mjs";

// The resize cursor of the resizable group, called directly: interaction state, limit flags and orientations in, a cursor out.

const axis = (orientation, disableCursor = false) => ({ orientation, mutableState: { disableCursor } });

primitiveTest("resizable_cursor: hover picks the axis cursor (Chromium names and the others), both axes give move/grab", async (page) => {
  const result = await page.evaluate(async (axes) => {
    const { cursorFor } = await import("chadcn/primitives/resizable_cursor");
    const cursor = (list, chromium, state = "hover") => cursorFor({ cursorFlags: 0, axes: list, state, chromium }) ?? null;
    return [
      cursor([axes.h], true), cursor([axes.v], true), cursor([axes.h, axes.v], true),
      cursor([axes.h], false), cursor([axes.v], false), cursor([axes.h, axes.v], false),
      cursor([axes.off], true), cursor([axes.h], true, "inactive"),
    ];
  }, { h: axis("horizontal"), v: axis("vertical"), off: axis("horizontal", true) });
  assert.deepEqual(result, ["ew-resize", "ns-resize", "move", "col-resize", "row-resize", "grab", null, null]);
});

primitiveTest("resizable_cursor: an active drag at a limit points back only (Chromium), and the flags follow the pointer movement", async (page) => {
  const result = await page.evaluate(async (h) => {
    const C = await import("chadcn/primitives/resizable_cursor");
    const active = (cursorFlags, chromium = true) => C.cursorFor({ cursorFlags, axes: [h], state: "active", chromium });
    return {
      cursors: [active(C.CURSOR_LEFT), active(C.CURSOR_RIGHT), active(C.CURSOR_LEFT | C.CURSOR_UP), active(C.CURSOR_RIGHT | C.CURSOR_DOWN),
        active(C.CURSOR_UP), active(C.CURSOR_DOWN), active(C.CURSOR_LEFT, false)],
      limits: [C.limitFlag({ orientation: "horizontal", delta: -1 }), C.limitFlag({ orientation: "horizontal", delta: 1 }),
        C.limitFlag({ orientation: "vertical", delta: -1 }), C.limitFlag({ orientation: "vertical", delta: 1 })],
      kept: C.nextCursorFlags({ flags: C.CURSOR_RIGHT, prevCursorFlags: C.CURSOR_LEFT | C.CURSOR_DOWN, movementX: 0, movementY: 0 }),
      moved: C.nextCursorFlags({ flags: C.CURSOR_RIGHT, prevCursorFlags: C.CURSOR_LEFT | C.CURSOR_DOWN, movementX: 3, movementY: 2 }),
      rule: C.cursorRule("ew-resize"),
    };
  }, axis("horizontal"));
  assert.deepEqual(result, {
    cursors: ["e-resize", "w-resize", "se-resize", "nw-resize", "s-resize", "n-resize", "col-resize"],
    limits: [1, 2, 4, 8],
    kept: 9,
    moved: 2,
    rule: "*, *:hover {cursor: ew-resize !important; }",
  });
});
