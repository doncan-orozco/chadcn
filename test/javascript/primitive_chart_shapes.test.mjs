import { assert, primitiveTest } from "./primitives_support.mjs";

primitiveTest("chart_shapes: the cursor is an SVG-namespace path with only the whitelisted attributes", async (page) => {
  const result = await page.evaluate(async () => {
    const { cursorElement } = await import("chadcn/primitives/chart_shapes");
    const node = cursorElement({
      tag: "path",
      attrs: { d: "M 0,0 h 5", fill: "#ccc", "stroke-width": 2, class: "recharts-curve", onclick: "alert(1)", href: "javascript:1", style: "x:y", onload: "1", nested: { a: 1 } },
    });
    return { namespace: node.namespaceURI, tag: node.localName, attributes: node.getAttributeNames().sort() };
  });
  assert.equal(result.namespace, "http://www.w3.org/2000/svg");
  assert.equal(result.tag, "path");
  assert.deepEqual(result.attributes, ["class", "d", "fill", "stroke-width"]);
});

primitiveTest("chart_shapes: a tag outside path and circle, or no spec, gives nothing", async (page) => {
  const result = await page.evaluate(async () => {
    const { cursorElement, activeDotElements } = await import("chadcn/primitives/chart_shapes");
    return [cursorElement({ tag: "script", attrs: {} }), cursorElement({ tag: "image", attrs: { href: "x" } }), cursorElement(null), cursorElement({ tag: "path", attrs: null }),
      activeDotElements(null).length, activeDotElements("x").length, activeDotElements([null, "a"]).length];
  });
  assert.deepEqual(result, [null, null, null, null, 0, 0, 0]);
});

primitiveTest("chart_shapes: every active dot is a g.recharts-active-dot around a circle.recharts-dot", async (page) => {
  const result = await page.evaluate(async () => {
    const { activeDotElements } = await import("chadcn/primitives/chart_shapes");
    const groups = activeDotElements([{ cx: "1", cy: "2", r: "4", fill: "red", class: "x", onclick: "1" }, { cx: "3", cy: "4", r: "4" }]);
    return groups.map((group) => ({ tag: group.localName, cls: group.getAttribute("class"), child: group.firstElementChild.localName, childClass: group.firstElementChild.getAttribute("class"),
      attributes: group.firstElementChild.getAttributeNames().sort(), namespace: group.firstElementChild.namespaceURI }));
  });
  assert.equal(result.length, 2);
  assert.deepEqual(result[0], { tag: "g", cls: "recharts-layer recharts-active-dot", child: "circle", childClass: "recharts-dot", attributes: ["class", "cx", "cy", "fill", "r"], namespace: "http://www.w3.org/2000/svg" });
  assert.equal(result[1].childClass, "recharts-dot");
});
