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
// Per item: its value, aria-checked, data-state, whether it has an indicator and its bubble input's checked (null without one; the
// input is the item's next sibling, which is the bubble-input contract).
const items = (page) => page.evaluate((selector) => [...document.querySelectorAll(`${selector} [data-slot=radio-group-item]`)].map((button) => {
  const input = button.nextElementSibling?.matches("input[aria-hidden=true]") ? button.nextElementSibling : null
  return {
    value: button.value,
    ariaChecked: button.getAttribute("aria-checked"),
    state: button.dataset.state,
    indicator: !!button.querySelector("[data-slot=radio-group-indicator]"),
    inputChecked: input ? input.checked : null
  }
}), group)
const unchecked = (value) => ({ value, ariaChecked: "false", state: "unchecked", indicator: false, inputChecked: false })
const checkedItem = (value) => ({ value, ariaChecked: "true", state: "checked", indicator: true, inputChecked: true })
// The roving focus moves focus on the next task (Radix setTimeout); wait for it, never for the clock.
const focusedOn = (page, value) => page.waitForFunction((value) => document.activeElement?.value === value, value)
// An arrow checks the item it focuses only while the key is down (Radix isArrowKeyPressedRef), so hold it until focus lands.
const arrow = async (page, key, value) => {
  await page.keyboard.down(key)
  await focusedOn(page, value)
  await page.keyboard.up(key)
}
const checked = async (page) => (await items(page)).filter((radio) => radio.ariaChecked === "true").map((radio) => radio.value)

browserTest("radio-group: a click checks the item, moves the indicator and reports value-change once", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  await recordChanges(page)
  await page.click(item("c"))
  await settle(page)
  assert.deepEqual(await items(page), [unchecked("a"), unchecked("b"), checkedItem("c")])
  // Control: clicking the checked item again changes nothing and reports nothing.
  await page.click(item("c"))
  await settle(page)
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
  await settle(page)
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
  await page.click("[type=reset]")
  await settle(page)
  assert.deepEqual(await checked(page), ["b"])
  assert.deepEqual((await items(page)).map((radio) => [radio.value, radio.inputChecked]), [["a", false], ["b", true], ["c", false]])
  assert.deepEqual(await changes(page), [{ value: "c" }, { value: "b" }])
})

browserTest("radio-group: outside a form the server-rendered bubble inputs are removed", async ({ open }) => {
  const page = await open("default")
  assert.equal(await page.locator(`${group} input[aria-hidden=true]`).count(), 0)
  // Control: inside a form they stay, one per item.
  const formPage = await open("form__bubble-inputs")
  assert.equal(await formPage.locator(`${group} input[aria-hidden=true]`).count(), 3)
})

browserTest("radio-group: disconnect removes the document key listeners it added and the form reset listener", async ({ open }) => {
  const page = await open("form__reset")
  // Track the document key listeners by reference, then reconnect so connect() registers under the spy.
  await page.evaluate(() => {
    window.__keyListeners = new Set()
    const add = document.addEventListener.bind(document)
    const remove = document.removeEventListener.bind(document)
    const tracked = (type) => type === "keydown" || type === "keyup"
    document.addEventListener = (type, listener, ...rest) => { if (tracked(type)) window.__keyListeners.add(listener); return add(type, listener, ...rest) }
    document.removeEventListener = (type, listener, ...rest) => { if (tracked(type)) window.__keyListeners.delete(listener); return remove(type, listener, ...rest) }
  })
  await page.evaluate(({ selector, identifier }) => new Promise((resolve) => {
    const element = document.querySelector(selector)
    element.removeAttribute("data-controller")
    requestAnimationFrame(() => {
      element.setAttribute("data-controller", identifier)
      requestAnimationFrame(resolve)
    })
  }), { selector: group, identifier: controller })
  assert.equal(await page.evaluate(() => window.__keyListeners.size), 2, "precondition: keydown and keyup are registered")
  await recordChanges(page)
  await page.click(item("c"))
  await page.evaluate((selector) => document.querySelector(selector).removeAttribute("data-controller"), group)
  await settle(page)
  assert.equal(await page.evaluate(() => window.__keyListeners.size), 0)
  await page.click("[type=reset]")
  await settle(page)
  // The host no longer matches the group selector once data-controller is gone.
  assert.deepEqual(await page.evaluate(() => [...document.querySelectorAll("[data-slot=radio-group-item]")].map((button) => button.getAttribute("aria-checked"))), ["false", "false", "true"])
  assert.deepEqual(await changes(page), [{ value: "c" }])
})

browserTest("radio-group: a Turbo snapshot keeps the checked item and the restored group answers the keyboard", async ({ open }) => {
  const page = await open("form__bubble-inputs")
  const errors = consoleErrors(page)
  await page.click(item("c"))
  const html = await snapshot(page, controller)
  await restore(page, controller, html)
  assert.deepEqual(await items(page), [unchecked("a"), unchecked("b"), checkedItem("c")])
  await recordChanges(page)
  await page.evaluate(() => document.activeElement?.blur())
  await page.keyboard.press("Tab")
  await focusedOn(page, "c")
  await arrow(page, "ArrowDown", "a")
  assert.deepEqual(await checked(page), ["a"])
  assert.deepEqual(await changes(page), [{ value: "a" }])
  assert.deepEqual(errors, [])
})
