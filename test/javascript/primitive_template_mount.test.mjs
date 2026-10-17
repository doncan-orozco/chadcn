import { assert, primitiveTest } from "./primitives_support.mjs";

const html = '<div id="host"><template id="tpl">text<p class="a">one</p><p class="b">two</p></template><span id="after"></span></div>';

primitiveTest("template_mount: inserts the template content right after the <template> by default", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate } = await import("shadcn/primitives/template_mount");
    const mount = mountTemplate(document.getElementById("tpl"));
    return {
      order: [...document.getElementById("host").children].map((el) => el.id || el.className || el.tagName),
      nodes: mount.nodes.map((el) => el.className),
    };
  });
  assert.deepEqual(result.order, ["tpl", "a", "b", "after"]);
  assert.deepEqual(result.nodes, ["a", "b"]);
}, { html });

primitiveTest("template_mount: `into` an element appends there (portal) and unmount removes every inserted node", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate } = await import("shadcn/primitives/template_mount");
    const tpl = document.getElementById("tpl");
    const mount = mountTemplate(tpl, { into: document.body });
    const mounted = { inBody: document.body.lastElementChild.className, text: document.body.textContent.includes("text") };
    mount.unmount();
    mount.unmount();
    return { mounted, left: document.querySelectorAll(".a, .b").length, textLeft: document.body.textContent.includes("text"), templateKept: !!document.getElementById("tpl") };
  });
  assert.deepEqual(result.mounted, { inBody: "b", text: true });
  assert.equal(result.left, 0);
  assert.equal(result.textLeft, false);
  assert.equal(result.templateKept, true);
}, { html });

primitiveTest("template_mount: every mount is a fresh clone (no state survives unmount)", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate } = await import("shadcn/primitives/template_mount");
    const tpl = document.getElementById("tpl");
    const first = mountTemplate(tpl);
    first.nodes[0].dataset.touched = "yes";
    first.unmount();
    const second = mountTemplate(tpl);
    return { fresh: second.nodes[0].dataset.touched ?? null, same: second.nodes[0] === first.nodes[0], templateContent: tpl.content.querySelectorAll(".a").length };
  });
  assert.deepEqual(result, { fresh: null, same: false, templateContent: 1 });
}, { html });
