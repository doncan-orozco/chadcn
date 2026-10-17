import { assert, primitiveTest } from "./primitives_support.mjs";

const html = '<div id="origin"><i id="before"></i><p id="el">x</p><i id="after"></i></div><div id="other"></div>';

primitiveTest("portal: moves the element into body by default", async (page) => {
  const parent = await page.evaluate(async () => {
    const { portal } = await import("shadcn/primitives/portal");
    portal(document.getElementById("el"));
    return document.getElementById("el").parentElement.tagName;
  });
  assert.equal(parent, "BODY");
}, { html });

primitiveTest("portal: release() puts the element back at its original position and leaves no placeholder", async (page) => {
  const result = await page.evaluate(async () => {
    const { portal } = await import("shadcn/primitives/portal");
    const el = document.getElementById("el");
    const release = portal(el, document.getElementById("other"));
    const moved = el.parentElement.id;
    release();
    const origin = document.getElementById("origin");
    const comments = [...origin.childNodes].filter((n) => n.nodeType === Node.COMMENT_NODE).length;
    return { moved, order: [...origin.children].map((c) => c.id), comments, otherEmpty: document.getElementById("other").children.length };
  });
  assert.equal(result.moved, "other");
  assert.deepEqual(result.order, ["before", "el", "after"]);
  assert.equal(result.comments, 0);
  assert.equal(result.otherEmpty, 0);
}, { html });

primitiveTest("portal: releasing twice does not throw or duplicate nodes", async (page) => {
  const result = await page.evaluate(async () => {
    const { portal } = await import("shadcn/primitives/portal");
    const el = document.getElementById("el");
    const release = portal(el, document.getElementById("other"));
    release();
    release();
    const origin = document.getElementById("origin");
    return { order: [...origin.children].map((c) => c.id), count: document.querySelectorAll("#el").length, otherEmpty: document.getElementById("other").children.length };
  });
  assert.deepEqual(result, { order: ["before", "el", "after"], count: 1, otherEmpty: 0 });
}, { html });

primitiveTest("portal: release() is a no-op when the placeholder was removed (no parent)", async (page) => {
  const result = await page.evaluate(async () => {
    const { portal } = await import("shadcn/primitives/portal");
    const el = document.getElementById("el");
    const release = portal(el, document.getElementById("other"));
    const origin = document.getElementById("origin");
    [...origin.childNodes].filter((n) => n.nodeType === Node.COMMENT_NODE).forEach((n) => n.remove());
    release();
    return { parent: el.parentElement.id, order: [...origin.children].map((c) => c.id) };
  });
  assert.deepEqual(result, { parent: "other", order: ["before", "after"] });
}, { html });
