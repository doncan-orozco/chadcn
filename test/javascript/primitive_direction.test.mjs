import { assert, primitiveTest } from "./primitives_support.mjs";

const html = '<div id="rtl" dir="rtl"></div><div id="bad" dir="auto"></div><div id="none"></div>';

primitiveTest("direction: local dir wins over the element dir attribute; the attribute wins over the ltr default", async (page) => {
  const result = await page.evaluate(async () => {
    const { direction } = await import("chadcn/primitives/direction");
    const el = (id) => document.getElementById(id);
    return {
      attribute: direction(el("rtl")),
      local: direction(el("rtl"), "ltr"),
      localOnPlain: direction(el("none"), "rtl"),
      fallback: direction(el("none")),
    };
  });
  assert.deepEqual(result, { attribute: "rtl", local: "ltr", localOnPlain: "rtl", fallback: "ltr" });
}, { html });

primitiveTest("direction: invalid values and a missing element fall back; html[dir] and ancestors are never read", async (page) => {
  const result = await page.evaluate(async () => {
    const { direction } = await import("chadcn/primitives/direction");
    document.documentElement.setAttribute("dir", "rtl");
    const child = document.createElement("div");
    document.getElementById("rtl").append(child);
    return {
      invalidAttribute: direction(document.getElementById("bad")),
      invalidLocal: direction(document.getElementById("none"), "sideways"),
      noElement: direction(null),
      underHtmlRtl: direction(document.getElementById("none")),
      childOfRtl: direction(child),
    };
  });
  assert.deepEqual(result, { invalidAttribute: "ltr", invalidLocal: "ltr", noElement: "ltr", underHtmlRtl: "ltr", childOfRtl: "ltr" });
}, { html });
