import { assert, primitiveTest } from "./primitives_support.mjs";

const html = '<div id="host"><template id="tpl">text<p class="a">one</p><p class="b">two</p></template><span id="after"></span></div>';

primitiveTest("template_mount: inserts the template content right after the <template> by default", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate } = await import("chadcn/primitives/template_mount");
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
    const { mountTemplate } = await import("chadcn/primitives/template_mount");
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
    const { mountTemplate } = await import("chadcn/primitives/template_mount");
    const tpl = document.getElementById("tpl");
    const first = mountTemplate(tpl);
    first.nodes[0].dataset.touched = "yes";
    first.unmount();
    const second = mountTemplate(tpl);
    return { fresh: second.nodes[0].dataset.touched ?? null, same: second.nodes[0] === first.nodes[0], templateContent: tpl.content.querySelectorAll(".a").length };
  });
  assert.deepEqual(result, { fresh: null, same: false, templateContent: 1 });
}, { html });

primitiveTest("template_mount: `into: \"replace\"` puts the clone in the template's place and unmount puts the template back", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate } = await import("chadcn/primitives/template_mount");
    const tpl = document.getElementById("tpl");
    const order = () => [...document.getElementById("host").children].map((el) => el.id || el.className);
    const mount = mountTemplate(tpl, { into: "replace" });
    const mounted = { order: order(), templateIn: tpl.isConnected };
    mount.unmount();
    mount.unmount();
    return { mounted, unmounted: order(), text: document.getElementById("host").textContent };
  });
  assert.deepEqual(result.mounted, { order: ["a", "b", "after"], templateIn: false });
  assert.deepEqual(result.unmounted, ["tpl", "after"]);
  assert.equal(result.text, "", "every inserted node, text included, is removed");
}, { html });

primitiveTest("template_mount: `into: \"replace\"` with an empty template keeps the template in place", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate } = await import("chadcn/primitives/template_mount");
    const tpl = document.createElement("template");
    document.getElementById("host").prepend(tpl);
    const mount = mountTemplate(tpl, { into: "replace" });
    const kept = tpl.isConnected;
    mount.unmount();
    return { kept, keptAfterUnmount: tpl.parentNode === document.getElementById("host"), nodes: mount.nodes.length };
  });
  assert.deepEqual(result, { kept: true, keptAfterUnmount: true, nodes: 0 });
}, { html });

primitiveTest("template_mount: `anchor` inserts right after another node, so a detached template can mount", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate } = await import("chadcn/primitives/template_mount");
    const tpl = document.getElementById("tpl");
    const anchor = document.createTextNode("");
    tpl.replaceWith(anchor);
    const mount = mountTemplate(tpl, { anchor });
    const order = [...document.getElementById("host").childNodes].map((node) => node === anchor ? "anchor" : (node.className || node.id || node.textContent));
    mount.unmount();
    return { order, left: [...document.getElementById("host").childNodes].map((node) => node === anchor ? "anchor" : node.id) };
  });
  assert.deepEqual(result.order, ["anchor", "text", "a", "b", "after"]);
  assert.deepEqual(result.left, ["anchor", "after"]);
}, { html });

primitiveTest("template_mount: mountedTemplate wraps server-rendered nodes as a mount of the template", async (page) => {
  const result = await page.evaluate(async () => {
    const { mountTemplate, mountedTemplate } = await import("chadcn/primitives/template_mount");
    const host = document.getElementById("host");
    const tpl = document.getElementById("tpl");
    const rendered = document.createElement("p");
    rendered.className = "server";
    tpl.replaceWith(rendered);

    const adopted = mountedTemplate(tpl, [rendered], { into: "replace" });
    const nodes = adopted.nodes.map((el) => el.className);
    adopted.unmount();
    const afterUnmount = [...host.children].map((el) => el.id || el.className);
    adopted.unmount();
    const afterSecondUnmount = [...host.children].map((el) => el.id || el.className);
    const again = mountTemplate(tpl, { into: "replace" });
    const remounted = [...host.children].map((el) => el.id || el.className);
    again.unmount();

    const box = document.createElement("div");
    box.append("x", document.createElement("span"));
    const inBox = mountedTemplate(tpl, [...box.childNodes]);
    inBox.unmount();
    return { nodes, afterUnmount, afterSecondUnmount, remounted, boxEmpty: box.childNodes.length, boxNodes: inBox.nodes.length };
  });
  assert.deepEqual(result.nodes, ["server"]);
  assert.deepEqual(result.afterUnmount, ["tpl", "after"], "unmount puts the template back where the server node was");
  assert.deepEqual(result.afterSecondUnmount, ["tpl", "after"], "a second unmount does not move the template again");
  assert.deepEqual(result.remounted, ["a", "b", "after"]);
  assert.deepEqual({ boxEmpty: result.boxEmpty, boxNodes: result.boxNodes }, { boxEmpty: 0, boxNodes: 1 });
}, { html });
