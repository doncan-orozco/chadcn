import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, reconnect, settle } from "./support.mjs"

// chadcn--toggle-group against its parity pages (spec: dev/port/specs/toggle-group.md): pointer and keyboard (arrows move the roving
// focus, Space and Enter press the focused item), aria-checked / aria-pressed and data-state, the value-change event, controlled mode,
// disabled items, a nested group that keeps its own items, and a reconnect that leaves one set of listeners.

browserTest.component = "toggle-group"

const group = host("chadcn--toggle-group")
const item = (value) => `${group} [data-chadcn--toggle-group-item-value="${value}"]`
const focusedValue = (page) => page.evaluate(() => document.activeElement.getAttribute("data-chadcn--toggle-group-item-value"))
// Roving focus moves the focus in a setTimeout (Radix focusFirst), so an arrow press settles before the next read.
const arrow = async (page, key) => {
  await page.keyboard.press(key)
  await settle(page)
}

// Every value-change dispatched, in order, with how it travels.
const recordValues = (page) => page.evaluate(() => {
  window.__values = []
  document.addEventListener("chadcn--toggle-group:value-change", (event) => {
    window.__values.push({ value: event.detail.value, bubbles: event.bubbles, cancelable: event.cancelable })
  })
})
const values = (page) => page.evaluate(() => window.__values.map((entry) => entry.value))

// data-state and the ARIA state of every direct item of a group (aria-checked for single, aria-pressed for multiple).
const states = (page, root = group) => page.locator(root).first().evaluate((el) => [...el.children]
  .filter((child) => child.matches("[data-slot=toggle-group-item]"))
  .map((child) => `${child.getAttribute("data-chadcn--toggle-group-item-value")}:${child.dataset.state}:${child.getAttribute("aria-checked") ?? child.getAttribute("aria-pressed")}`))

browserTest("toggle-group: single selects on click, switches to another item and deselects it again", async ({ open }) => {
  const page = await open("default__single")
  await recordValues(page)
  await page.click(item("bold"))
  assert.deepEqual(await states(page), ["bold:on:true", "italic:off:false", "strikethrough:off:false"])
  await page.click(item("italic"))
  assert.deepEqual(await states(page), ["bold:off:false", "italic:on:true", "strikethrough:off:false"])
  await page.click(item("italic"))
  assert.deepEqual(await states(page), ["bold:off:false", "italic:off:false", "strikethrough:off:false"])
  assert.deepEqual(await page.evaluate(() => window.__values), [
    { value: "bold", bubbles: true, cancelable: false },
    { value: "italic", bubbles: true, cancelable: false },
    { value: "", bubbles: true, cancelable: false }
  ])
})

browserTest("toggle-group: multiple presses items independently, in activation order, with aria-pressed", async ({ open }) => {
  const page = await open("default__multiple")
  await recordValues(page)
  await page.click(item("italic"))
  await page.click(item("bold"))
  await page.click(item("italic"))
  assert.deepEqual(await states(page), ["bold:on:true", "italic:off:false", "strikethrough:off:false"])
  assert.deepEqual(await values(page), [["italic"], ["italic", "bold"], ["bold"]])
})

browserTest("toggle-group: arrows move the roving focus without pressing, Space and Enter press the focused item", async ({ open }) => {
  const page = await open("default__single")
  await recordValues(page)
  await page.keyboard.press("Tab")
  assert.equal(await focusedValue(page), "bold", "Tab enters on the first item")
  await arrow(page, "ArrowRight")
  assert.equal(await focusedValue(page), "italic")
  assert.deepEqual(await values(page), [], "arrows only move focus")
  await page.keyboard.press("Space")
  await arrow(page, "ArrowRight")
  await arrow(page, "ArrowRight")
  assert.equal(await focusedValue(page), "bold", "loop wraps to the first item")
  await page.keyboard.press("Enter")
  assert.deepEqual(await values(page), ["italic", "bold"])
  assert.deepEqual(await states(page), ["bold:on:true", "italic:off:false", "strikethrough:off:false"])
})

browserTest("toggle-group: a controlled group dispatches the requested value and leaves the DOM to the server", async ({ open }) => {
  const page = await open("controlled__single")
  await recordValues(page)
  const before = await states(page)
  const target = await page.locator(`${group} [data-slot=toggle-group-item][data-state=off]`).first()
  await target.click()
  assert.deepEqual(await states(page), before)
  assert.equal((await values(page)).length, 1)
})

browserTest("toggle-group: a disabled item is not pressed by a click", async ({ open }) => {
  const page = await open("disabled__item")
  await recordValues(page)
  const before = await states(page)
  await page.locator(`${group} [data-slot=toggle-group-item]:enabled`).first().click()
  const pressed = await states(page)
  assert.notDeepEqual(pressed, before, "control: an enabled item is pressed by the same click")
  assert.equal((await values(page)).length, 1)
  await page.locator(`${group} [data-slot=toggle-group-item]:disabled`).first().click({ force: true })
  assert.deepEqual(await states(page), pressed)
  assert.equal((await values(page)).length, 1, "the disabled click dispatched nothing more")
})

// Advisory of dev/port/REPORT.md: the item lookup matched the items of a nested group too, so pressing an outer item also flipped the
// inner item with the same value.
browserTest("toggle-group: a group nested in another keeps its own items", async ({ open }) => {
  const page = await open("default__single")
  await page.evaluate(() => {
    const outer = document.querySelector("[data-controller~='chadcn--toggle-group']")
    const inner = outer.cloneNode(true)
    inner.id = "inner"
    outer.append(inner)
  })
  await settle(page)
  await recordValues(page)
  const outerItem = (value) => `${group} > [data-chadcn--toggle-group-item-value="${value}"]`
  await page.click(outerItem("bold"))
  assert.deepEqual(await states(page), ["bold:on:true", "italic:off:false", "strikethrough:off:false"])
  assert.deepEqual(await states(page, "#inner"), ["bold:off:false", "italic:off:false", "strikethrough:off:false"], "the inner bold stays off")
  await page.click("#inner [data-chadcn--toggle-group-item-value='italic']")
  assert.deepEqual(await states(page, "#inner"), ["bold:off:false", "italic:on:true", "strikethrough:off:false"])
  assert.deepEqual(await states(page), ["bold:on:true", "italic:off:false", "strikethrough:off:false"], "the outer group is untouched")
  await page.click(outerItem("italic"))
  assert.deepEqual(await states(page, "#inner"), ["bold:off:false", "italic:on:true", "strikethrough:off:false"], "the outer render skips inner items")
  assert.deepEqual(await values(page), ["bold", "italic", "italic"])
})

browserTest("toggle-group: a reconnected group reads its value from the DOM and dispatches once per click", async ({ open }) => {
  const page = await open("default__multiple")
  const errors = consoleErrors(page)
  await page.click(item("bold"))
  await reconnect(page, "chadcn--toggle-group")
  await recordValues(page)
  await page.click(item("italic"))
  assert.deepEqual(await values(page), [["bold", "italic"]])
  await arrow(page, "ArrowLeft")
  assert.equal(await focusedValue(page), "bold", "one roving focus handler moves one step")
  assert.deepEqual(errors, [])
})
