import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// RadioGroup (spec dev/port/specs/radio-group.md). The scenarios compare the DOM after clicks, Tab and arrow keys with React; this
// file pins what they cannot see: the public value-change event and its detail, a caller's preventDefault, Enter that never selects,
// the controlled mode, the bubble inputs' native click and the form reset, the document listeners released on disconnect and a
// Turbo cache restore.
browserTest.component = "radio-group"
const controller = "chadcn--radio-group"
const group = host(controller)
const item = (value) => `${group} [data-slot=radio-group-item][value="${value}"]`

const recordChanges = (page) => page.evaluate(() => {
  window.__changes = []
  document.addEventListener("chadcn--radio-group:value-change", (event) => window.__changes.push(event.detail))
})
const changes = (page) => page.evaluate(() => window.__changes)
// Per item: [value, aria-checked, data-state, has an indicator, bubble input checked or null].
const items = (page) => page.evaluate((selector) => [...document.querySelectorAll(`${selector} [data-slot=radio-group-item]`)].map((button) => {
  const input = button.nextElementSibling?.matches("input[aria-hidden=true]") ? button.nextElementSibling : null
  return [button.value, button.getAttribute("aria-checked"), button.dataset.state, !!button.querySelector("[data-slot=radio-group-indicator]"), input ? input.checked : null]
}), group)
// The roving focus moves focus on the next task (Radix setTimeout); wait for it, never for the clock.
const focusedOn = (page, value) => page.waitForFunction((value) => document.activeElement?.value === value, value)
// An arrow checks the item it focuses only while the key is down (Radix isArrowKeyPressedRef), so hold it until focus lands.
const arrow = async (page, key, value) => {
  await page.keyboard.down(key)
  await focusedOn(page, value)
  await page.keyboard.up(key)
}
const checked = async (page) => (await items(page)).filter(([, aria]) => aria === "true").map(([value]) => value)

browserTest("radio-group: a click checks the item, moves the indicator and reports value-change once", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  await recordChanges(page)
  await page.click(item("c"))
  await settle(page)
  assert.deepEqual(await items(page), [
    ["a", "false", "unchecked", false, false],
    ["b", "false", "unchecked", false, false],
    ["c", "true", "checked", true, true]
  ])
  // Control: clicking the checked item again changes nothing and reports nothing.
  await page.click(item("c"))
  assert.deepEqual(await changes(page), [{ value: "c" }])
})

browserTest("radio-group: an arrow key moves focus and checks the focused item, Home and End only move focus", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  await recordChanges(page)
  await page.keyboard.press("Tab")
  assert.equal(await page.evaluate(() => document.activeElement.value), "b", "precondition: Tab enters on the checked item")
  await arrow(page, "ArrowDown", "c")
  assert.deepEqual(await checked(page), ["c"])
  await arrow(page, "Home", "a")
  assert.deepEqual(await checked(page), ["c"])
  assert.deepEqual(await changes(page), [{ value: "c" }])
})

browserTest("radio-group: a programmatic focus does not check the item", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  await recordChanges(page)
  await page.evaluate((selector) => document.querySelector(selector).focus(), item("a"))
  await settle(page)
  assert.deepEqual(await checked(page), ["b"])
  assert.deepEqual(await changes(page), [])
})

browserTest("radio-group: Enter is prevented and never checks, Space checks", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  await recordChanges(page)
  await page.evaluate(() => {
    window.__enterPrevented = []
    document.addEventListener("keydown", (event) => { if (event.key === "Enter") window.__enterPrevented.push(event.defaultPrevented) })
  })
  await page.evaluate((selector) => document.querySelector(selector).focus(), item("a"))
  await page.keyboard.press("Enter")
  assert.deepEqual(await page.evaluate(() => window.__enterPrevented), [true])
  assert.deepEqual(await checked(page), ["b"])
  // Control: Space on the same item checks it.
  await page.keyboard.press("Space")
  assert.deepEqual(await checked(page), ["a"])
  assert.deepEqual(await changes(page), [{ value: "a" }])
})

browserTest("radio-group: a caller that prevents the click keeps the value and nothing is reported", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  await recordChanges(page)
  await page.evaluate(() => {
    document.addEventListener("click", (event) => { if (event.target.closest("[data-slot=radio-group-item]")) event.preventDefault() }, { capture: true })
  })
  await page.click(item("a"))
  assert.deepEqual(await checked(page), ["b"])
  assert.deepEqual(await changes(page), [])
})

browserTest("radio-group: controlled reports the requested value and leaves the DOM to the caller", async ({ open }) => {
  const page = await open("controlled-value")
  await recordChanges(page)
  await page.click(item("c"))
  await settle(page)
  assert.deepEqual(await checked(page), ["b"])
  assert.equal(await page.locator(`${item("b")} [data-slot=radio-group-indicator]`).count(), 1)
  assert.deepEqual(await changes(page), [{ value: "c" }])
})

browserTest("radio-group: in a form the bubble inputs submit the value and a native click reaches the form", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  await page.evaluate(() => {
    window.__formClicks = []
    document.querySelector("form").addEventListener("click", (event) => {
      if (event.target.matches("input[aria-hidden=true]")) window.__formClicks.push([event.target.value, event.target.checked])
    })
  })
  assert.equal(await page.evaluate(() => new FormData(document.querySelector("form")).get("plan")), "b")
  await page.click(item("a"))
  assert.equal(await page.evaluate(() => new FormData(document.querySelector("form")).get("plan")), "a")
  // Every item whose checked changed syncs its input, in DOM order.
  assert.deepEqual(await page.evaluate(() => window.__formClicks), [["a", true], ["b", false]])
})

browserTest("radio-group: a form reset restores the initial value and reports it", async ({ open }) => {
  const page = await open("form__reset")
  await recordChanges(page)
  await page.click(item("c"))
  await page.click("#reset")
  await settle(page)
  assert.deepEqual(await checked(page), ["b"])
  assert.deepEqual((await items(page)).map(([value, , , , input]) => [value, input]), [["a", false], ["b", true], ["c", false]])
  assert.deepEqual(await changes(page), [{ value: "c" }, { value: "b" }])
})

browserTest("radio-group: outside a form the server-rendered bubble inputs are removed", async ({ open }) => {
  const page = await open("default")
  assert.equal(await page.locator(`${group} input[aria-hidden=true]`).count(), 0)
  // Control: inside a form they stay, one per item.
  const form = await open("form__bubble-inputs")
  assert.equal(await form.locator(`${group} input[aria-hidden=true]`).count(), 3)
})

browserTest("radio-group: disconnect removes the document key listeners and the form reset listener", async ({ open }) => {
  const page = await open("form__reset")
  await recordChanges(page)
  await page.evaluate(() => {
    window.__listeners = { add: [], remove: [] }
    const add = document.addEventListener.bind(document)
    const remove = document.removeEventListener.bind(document)
    document.addEventListener = (type, ...rest) => { window.__listeners.add.push(type); return add(type, ...rest) }
    document.removeEventListener = (type, ...rest) => { window.__listeners.remove.push(type); return remove(type, ...rest) }
  })
  await page.click(item("c"))
  await page.evaluate((selector) => document.querySelector(selector).removeAttribute("data-controller"), group)
  await settle(page)
  const removed = await page.evaluate(() => window.__listeners.remove)
  assert.ok(removed.includes("keydown") && removed.includes("keyup"), removed.join(","))
  await page.click("#reset")
  await settle(page)
  assert.deepEqual(await page.evaluate(() => [...document.querySelectorAll("[data-slot=radio-group-item]")].map((b) => b.getAttribute("aria-checked"))), ["false", "false", "true"])
  assert.deepEqual(await changes(page), [{ value: "c" }])
})

browserTest("radio-group: a Turbo snapshot keeps the checked item and the restored group answers the keyboard", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  const errors = consoleErrors(page)
  await page.click(item("c"))
  const html = await snapshot(page, controller)
  await restore(page, controller, html)
  assert.deepEqual(await items(page), [
    ["a", "false", "unchecked", false, false],
    ["b", "false", "unchecked", false, false],
    ["c", "true", "checked", true, true]
  ])
  await recordChanges(page)
  await page.evaluate(() => document.activeElement?.blur())
  await page.keyboard.press("Tab")
  await focusedOn(page, "c")
  await arrow(page, "ArrowDown", "a")
  assert.deepEqual(await checked(page), ["a"])
  assert.deepEqual(await changes(page), [{ value: "a" }])
  assert.deepEqual(errors, [])
})
