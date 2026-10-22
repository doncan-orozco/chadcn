import { assert, primitiveTest } from "./primitives_support.mjs";

const html = `<div id="list">
  <button data-radix-collection-item id="a">Apple</button>
  <button data-radix-collection-item id="b" data-disabled>Banana</button>
  <button data-radix-collection-item id="c" disabled>Cherry</button>
  <button data-radix-collection-item id="d" data-text-value="Date!">  ignored </button>
  <span id="plain">not an item</span>
</div>`;

primitiveTest("collection: items() returns enabled items in DOM order; includeDisabled keeps data-disabled and disabled ones", async (page) => {
  const result = await page.evaluate(async () => {
    const { items } = await import("chadcn/primitives/collection");
    const list = document.getElementById("list");
    const ids = (nodes) => nodes.map((n) => n.id);
    const before = ids(items(list));
    // DOM order is the registry: moving a node changes the order, no re-registration needed.
    list.append(document.getElementById("a"));
    return { enabled: before, all: ids(items(list, { includeDisabled: true })), reordered: ids(items(list)) };
  });
  assert.deepEqual(result.enabled, ["a", "d"]);
  assert.deepEqual(result.all, ["b", "c", "d", "a"]);
  assert.deepEqual(result.reordered, ["d", "a"]);
}, { html });

primitiveTest("collection: isDisabled reads data-disabled or the native property; constants name the item attribute", async (page) => {
  const result = await page.evaluate(async () => {
    const { isDisabled, ITEM_ATTR, ITEM_SELECTOR } = await import("chadcn/primitives/collection");
    const el = (id) => document.getElementById(id);
    return { a: isDisabled(el("a")), b: isDisabled(el("b")), c: isDisabled(el("c")), span: isDisabled(el("plain")), ITEM_ATTR, ITEM_SELECTOR };
  });
  assert.deepEqual(result, { a: false, b: true, c: true, span: false, ITEM_ATTR: "data-radix-collection-item", ITEM_SELECTOR: "[data-radix-collection-item]" });
}, { html });

primitiveTest("collection: textValue prefers data-text-value, else trimmed text; wrapArray rotates from a start index", async (page) => {
  const result = await page.evaluate(async () => {
    const { textValue, wrapArray } = await import("chadcn/primitives/collection");
    const el = (id) => document.getElementById(id);
    return {
      override: textValue(el("d")), text: textValue(el("a")),
      rotated: wrapArray([1, 2, 3, 4], 2), same: wrapArray([1, 2, 3], 0), empty: wrapArray([], 0),
    };
  });
  assert.deepEqual(result, { override: "Date!", text: "Apple", rotated: [3, 4, 1, 2], same: [1, 2, 3], empty: [] });
}, { html });

primitiveTest("collection: items of a nested collection inside the container are included (documented divergence)", async (page) => {
  const ids = await page.evaluate(async () => {
    const { items } = await import("chadcn/primitives/collection");
    const nested = document.createElement("div");
    nested.innerHTML = '<button data-radix-collection-item id="inner">Inner</button>';
    document.getElementById("list").append(nested);
    return items(document.getElementById("list")).map((n) => n.id);
  });
  assert.deepEqual(ids, ["a", "d", "inner"]);
}, { html });
