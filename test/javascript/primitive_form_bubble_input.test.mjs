import { assert, frames, primitiveTest } from "./primitives_support.mjs";

const html = `<form id="form"><button type="button" id="control" role="checkbox" style="width:40px;height:20px">c</button></form>
  <button type="button" id="loose">loose</button>`;

const make = (options, control = "control") => `
  const { FormBubbleInput } = await import("shadcn/primitives/form_bubble_input");
  const control = document.getElementById("${control}");
  const bubble = new FormBubbleInput(control, ${options});
  window.__bubble = bubble;
`;
const run = (page, body) => page.evaluate(new Function(`return (async () => { ${body} })()`));

primitiveTest("form_bubble_input: renders a hidden sibling input after the control only inside a form", async (page) => {
  const result = await run(page, `${make('{ type: "checkbox", name: "terms", value: "yes", checked: true, required: true }')}
    const input = control.nextElementSibling;
    const loose = new FormBubbleInput(document.getElementById("loose"), { type: "checkbox" });
    return {
      present: bubble.present, loosePresent: loose.present,
      tag: input.tagName, type: input.type, name: input.name, value: input.value, checked: input.checked, required: input.required,
      ariaHidden: input.getAttribute("aria-hidden"), tabindex: input.tabIndex,
      style: { position: input.style.position, pointerEvents: input.style.pointerEvents, opacity: input.style.opacity, transform: input.style.transform, width: input.style.width, height: input.style.height },
      isFormControl: [FormBubbleInput.isFormControl(control), FormBubbleInput.isFormControl(document.getElementById("loose")), FormBubbleInput.isFormControl(document.getElementById("loose"), "form")],
    };`);
  assert.deepEqual(result, {
    present: true, loosePresent: false, tag: "INPUT", type: "checkbox", name: "terms", value: "yes", checked: true, required: true,
    ariaHidden: "true", tabindex: -1,
    style: { position: "absolute", pointerEvents: "none", opacity: "0", transform: "translateX(-100%)", width: "40px", height: "20px" },
    isFormControl: [true, false, true],
  });
}, { html });

primitiveTest("form_bubble_input: sync() updates the native value and dispatches one click per change", async (page) => {
  const result = await run(page, `${make('{ type: "checkbox", name: "t" }')}
    const clicks = [];
    document.getElementById("form").addEventListener("click", (event) => clicks.push({ target: event.target.tagName, bubbles: event.bubbles }));
    const input = control.nextElementSibling;
    bubble.sync({ checked: true });
    bubble.sync({ checked: true });
    const checked = input.checked;
    bubble.sync({ checked: false });
    return { clicks, checked, unchecked: input.checked, form: new FormData(document.getElementById("form")).has("t") };`);
  assert.deepEqual(result.clicks, [{ target: "INPUT", bubbles: true }, { target: "INPUT", bubbles: true }]);
  assert.deepEqual([result.checked, result.unchecked, result.form], [true, false, false]);
}, { html });

primitiveTest("form_bubble_input: a user interaction whose control click was stopped does not bubble the click", async (page) => {
  const clicks = await run(page, `${make('{ type: "checkbox" }')}
    let count = 0;
    document.getElementById("form").addEventListener("click", () => count++);
    bubble.sync({ checked: true }, { userInteraction: true, propagationStopped: true });
    return count;`);
  assert.equal(clicks, 0);
}, { html });

primitiveTest("form_bubble_input: indeterminate overrides checked and is reflected on the native input", async (page) => {
  const result = await run(page, `${make('{ type: "checkbox", checked: true, indeterminate: true }')}
    const input = control.nextElementSibling;
    const initial = { checked: input.checked, indeterminate: input.indeterminate };
    bubble.sync({ indeterminate: false, checked: true });
    return { initial, after: { checked: input.checked, indeterminate: input.indeterminate } };`);
  assert.deepEqual(result, { initial: { checked: false, indeterminate: true }, after: { checked: true, indeterminate: false } });
}, { html });

primitiveTest("form_bubble_input: a server-rendered bubble input is adopted, not duplicated", async (page) => {
  const result = await run(page, `
    document.getElementById("control").insertAdjacentHTML("afterend", '<input id="ssr" type="checkbox" aria-hidden="true" tabindex="-1">');
    ${make('{ type: "checkbox", name: "n" }')}
    return { adopted: control.nextElementSibling.id, inputs: document.querySelectorAll("#form input").length, name: document.getElementById("ssr").name };`);
  assert.deepEqual(result, { adopted: "ssr", inputs: 1, name: "n" });
}, { html });

primitiveTest("form_bubble_input: select mirrors options and dispatches a bubbling change when the value differs", async (page) => {
  const result = await run(page, `${make('{ type: "select", name: "s", value: "b", options: [{ value: "a", label: "A" }, { value: "b", label: "B" }] }')}
    const changes = [];
    document.getElementById("form").addEventListener("change", (event) => changes.push(event.target.value));
    const select = control.nextElementSibling;
    const initial = { tag: select.tagName, options: [...select.options].map((o) => o.value + ":" + o.text), value: select.value, clip: select.style.clip };
    bubble.sync({ value: "b" });
    bubble.sync({ value: "a" });
    return { initial, changes, value: select.value };`);
  assert.deepEqual(result.initial, { tag: "SELECT", options: ["a:A", "b:B"], value: "b", clip: "rect(0px, 0px, 0px, 0px)" });
  assert.deepEqual(result.changes, ["a"]);
  assert.equal(result.value, "a");
}, { html });

primitiveTest("form_bubble_input: form reset runs onReset; release() removes the input and the reset listener", async (page) => {
  const result = await run(page, `
    let resets = 0;
    ${make("{ type: \"checkbox\", onReset: () => resets++ }")}
    const form = document.getElementById("form");
    form.reset();
    const afterReset = resets;
    bubble.release();
    bubble.release();
    form.reset();
    bubble.sync({ checked: true });
    return { afterReset, resets, inputs: form.querySelectorAll("input").length, present: bubble.present };`);
  assert.deepEqual(result, { afterReset: 1, resets: 1, inputs: 0, present: false });
}, { html });

primitiveTest("form_bubble_input: the input follows the control size after a resize (ResizeObserver) and stops on release", async (page) => {
  await run(page, make('{ type: "checkbox" }'));
  await page.evaluate(() => { document.getElementById("control").style.width = "60px" });
  await frames(page);
  await frames(page);
  assert.equal(await page.evaluate(() => document.getElementById("control").nextElementSibling.style.width), "60px");
  await page.evaluate(() => { const input = document.getElementById("control").nextElementSibling; window.__bubble.release(); input.style.width = "1px"; document.getElementById("control").style.width = "90px"; window.__input = input });
  await frames(page);
  await frames(page);
  assert.equal(await page.evaluate(() => window.__input.style.width), "1px");
}, { html });

primitiveTest("form_bubble_input: a radio mirrors checked and dispatches a click on change", async (page) => {
  const result = await run(page, `${make('{ type: "radio", name: "r", value: "x" }')}
    const clicks = [];
    document.getElementById("form").addEventListener("click", (event) => clicks.push(event.target.type));
    const input = control.nextElementSibling;
    bubble.sync({ checked: true });
    return { type: input.type, value: input.value, checked: input.checked, clicks };`);
  assert.deepEqual(result, { type: "radio", value: "x", checked: true, clicks: ["radio"] });
}, { html });

primitiveTest("form_bubble_input: sync() applies disabled and required to the native input", async (page) => {
  const result = await run(page, `${make('{ type: "checkbox" }')}
    const input = control.nextElementSibling;
    const before = [input.disabled, input.required];
    bubble.sync({ disabled: true, required: true });
    const during = [input.disabled, input.required];
    bubble.sync({ disabled: false, required: false });
    return { before, during, after: [input.disabled, input.required] };`);
  assert.deepEqual(result, { before: [false, false], during: [true, true], after: [false, false] });
}, { html });
