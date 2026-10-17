import { assert, primitiveTest } from "./primitives_support.mjs";

const html = "<main id=\"app\"><button>x</button></main>";

primitiveTest("focus_guards: inserts a focusable invisible guard at both edges of body and release() removes them", async (page) => {
  const result = await page.evaluate(async () => {
    const { focusGuards } = await import("shadcn/primitives/focus_guards");
    const release = focusGuards();
    const nodes = [...document.querySelectorAll("[data-radix-focus-guard]")];
    const edges = { first: document.body.firstElementChild === nodes[0], last: document.body.lastElementChild === nodes[1], count: nodes.length };
    const guard = nodes[0];
    const shape = { tabIndex: guard.tabIndex, opacity: guard.style.opacity, position: guard.style.position, pointerEvents: guard.style.pointerEvents };
    release();
    return { edges, shape, left: document.querySelectorAll("[data-radix-focus-guard]").length };
  });
  assert.deepEqual(result.edges, { first: true, last: true, count: 2 });
  assert.deepEqual(result.shape, { tabIndex: 0, opacity: "0", position: "fixed", pointerEvents: "none" });
  assert.equal(result.left, 0);
}, { html });

primitiveTest("focus_guards: ref-counted, nested locks share the guards and the last release removes them", async (page) => {
  const result = await page.evaluate(async () => {
    const { focusGuards } = await import("shadcn/primitives/focus_guards");
    const count = () => document.querySelectorAll("[data-radix-focus-guard]").length;
    const first = focusGuards();
    const second = focusGuards();
    const shared = count();
    first();
    const afterFirst = count();
    second();
    return { shared, afterFirst, afterLast: count() };
  });
  assert.deepEqual(result, { shared: 2, afterFirst: 2, afterLast: 0 });
}, { html });

primitiveTest("focus_guards: guards are re-pinned to the body edges when content was added in between", async (page) => {
  const result = await page.evaluate(async () => {
    const { focusGuards } = await import("shadcn/primitives/focus_guards");
    const first = focusGuards();
    document.body.append(Object.assign(document.createElement("div"), { id: "late" }));
    const second = focusGuards();
    const lastIsGuard = document.body.lastElementChild.hasAttribute("data-radix-focus-guard");
    const total = document.querySelectorAll("[data-radix-focus-guard]").length;
    first(); second();
    return { lastIsGuard, total };
  });
  assert.deepEqual(result, { lastIsGuard: true, total: 2 });
}, { html });
