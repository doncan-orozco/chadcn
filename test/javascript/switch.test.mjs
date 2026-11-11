import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, reconnect, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// Switch (spec dev/port/specs/switch.md). The scenarios compare the DOM after clicks and keys with React; this file pins what they
// cannot see: the public checked-change event and its detail, a caller's preventDefault, the controlled mode (the event without the
// DOM change), the bubble input's native click and the form reset, the release on disconnect and a Turbo cache restore.
browserTest.component = "switch"
const controller = "chadcn--switch"
const control = host(controller)

const recordChanges = (page) => page.evaluate(() => {
  window.__changes = []
  document.addEventListener("chadcn--switch:checked-change", (event) => window.__changes.push(event.detail))
})
const changes = (page) => page.evaluate(() => window.__changes)
const state = (page) => page.evaluate((selector) => {
  const element = document.querySelector(selector)
  return { checked: element.getAttribute("aria-checked"), state: element.dataset.state, thumb: element.querySelector("[data-slot=switch-thumb]").dataset.state }
}, control)
// Native events that reach the form from the bubble input (Radix BubbleInput dispatches a bubbling click on the hidden input).
const recordFormClicks = (page) => page.evaluate(() => {
  window.__formClicks = []
  document.querySelector("form").addEventListener("click", (event) => {
    if (event.target.matches("input[aria-hidden=true]")) window.__formClicks.push(event.target.checked)
  })
})
const bubble = (page) => page.evaluate((selector) => {
  const input = document.querySelector(selector).nextElementSibling
  return input?.matches("input[aria-hidden=true]") ? { checked: input.checked, name: input.name } : null
}, control)

browserTest("switch: a click toggles aria-checked and data-state on the root and the thumb and reports checked-change", async ({ open }) => {
  const page = await open("default")
  await recordChanges(page)
  assert.deepEqual(await state(page), { checked: "false", state: "unchecked", thumb: "unchecked" })
  await page.click(control)
  assert.deepEqual(await state(page), { checked: "true", state: "checked", thumb: "checked" })
  await page.click(control)
  assert.deepEqual(await state(page), { checked: "false", state: "unchecked", thumb: "unchecked" })
  assert.deepEqual(await changes(page), [{ checked: true }, { checked: false }])
})

browserTest("switch: Space and Enter toggle through the native button and report checked-change", async ({ open }) => {
  const page = await open("default")
  await recordChanges(page)
  await page.focus(control)
  await page.keyboard.press("Space")
  assert.equal((await state(page)).checked, "true")
  await page.keyboard.press("Enter")
  assert.equal((await state(page)).checked, "false")
  assert.deepEqual(await changes(page), [{ checked: true }, { checked: false }])
})

browserTest("switch: a caller that prevents the click keeps the state and no checked-change fires", async ({ open }) => {
  const page = await open("default")
  await recordChanges(page)
  await page.evaluate((selector) => {
    document.addEventListener("click", (event) => { if (event.target.closest(selector)) event.preventDefault() }, { capture: true })
  }, control)
  await page.click(control)
  await settle(page)
  assert.equal((await state(page)).checked, "false")
  assert.deepEqual(await changes(page), [])
})

browserTest("switch: controlled reports the requested state and leaves the DOM to the caller", async ({ open }) => {
  const page = await open("controlled__checked-true__click-stays")
  await recordChanges(page)
  await page.click(control)
  assert.deepEqual(await state(page), { checked: "true", state: "checked", thumb: "checked" })
  assert.deepEqual(await changes(page), [{ checked: false }])
})

browserTest("switch: in a form the bubble input follows the state and a native click reaches the form", async ({ open }) => {
  const page = await open("form__bubble-input")
  await recordFormClicks(page)
  assert.deepEqual(await bubble(page), { checked: false, name: "notifications" })
  await page.click(control)
  assert.deepEqual(await bubble(page), { checked: true, name: "notifications" })
  assert.deepEqual(await page.evaluate(() => window.__formClicks), [true])
  assert.equal(await page.evaluate(() => new FormData(document.querySelector("form")).get("notifications")), "on")
})

// A caller's onClick runs before Radix's (composeEventHandlers): the listener goes on the switch first, then the controller
// reconnects so its action listener is added after it.
const stopClicksBeforeController = (page) => page.evaluate(({ selector, identifier }) => new Promise((resolve) => {
  const element = document.querySelector(selector)
  element.addEventListener("click", (event) => event.stopPropagation())
  element.removeAttribute("data-controller")
  requestAnimationFrame(() => {
    element.setAttribute("data-controller", identifier)
    requestAnimationFrame(resolve)
  })
}), { selector: control, identifier: controller })

browserTest("switch: a click stopped by the caller still toggles but the bubble input's click does not bubble", async ({ open }) => {
  const page = await open("form__bubble-input")
  await recordFormClicks(page)
  await stopClicksBeforeController(page)
  await page.click(control)
  assert.deepEqual(await bubble(page), { checked: true, name: "notifications" })
  assert.deepEqual(await page.evaluate(() => window.__formClicks), [])
})

browserTest("switch: a form reset restores the initial state and reports it", async ({ open }) => {
  const page = await open("form__reset-restores-initial")
  await recordChanges(page)
  await page.click(control)
  assert.equal((await state(page)).checked, "true")
  await page.evaluate(() => document.querySelector("form").reset())
  await settle(page)
  assert.deepEqual(await state(page), { checked: "false", state: "unchecked", thumb: "unchecked" })
  assert.equal((await bubble(page)).checked, false)
  assert.deepEqual(await changes(page), [{ checked: true }, { checked: false }])
})

browserTest("switch: outside a form no bubble input is rendered", async ({ open }) => {
  const page = await open("api__name-outside-form-no-bubble-input")
  assert.equal(await bubble(page), null)
  // Control: the switch still toggles without one.
  await page.click(control)
  assert.equal((await state(page)).checked, "true")
})

browserTest("switch: a disconnected switch no longer answers the form reset", async ({ open }) => {
  const page = await open("form__reset-restores-initial")
  await recordChanges(page)
  await page.click(control)
  await page.evaluate((selector) => {
    const element = document.querySelector(selector)
    window.__detached = element
    element.removeAttribute("data-controller")
  }, control)
  await settle(page)
  await page.evaluate(() => document.querySelector("form").reset())
  await settle(page)
  assert.equal(await page.evaluate(() => window.__detached.getAttribute("aria-checked")), "true")
  assert.deepEqual(await changes(page), [{ checked: true }])
})

browserTest("switch: a reconnect keeps the state and the bubble input, and the switch toggles again", async ({ open }) => {
  const page = await open("form__bubble-input")
  const errors = consoleErrors(page)
  await page.click(control)
  await reconnect(page, controller, { anchor: "bubble-input" })
  await settle(page)
  assert.equal((await state(page)).checked, "true")
  assert.equal(await page.locator("input[aria-hidden=true]").count(), 1)
  await page.click(control)
  assert.equal((await state(page)).checked, "false")
  assert.equal((await bubble(page)).checked, false)
  assert.deepEqual(errors, [])
})

browserTest("switch: a Turbo snapshot keeps the checked state and the restored switch toggles", async ({ open }) => {
  const page = await open("default")
  await page.click(control)
  const html = await snapshot(page, controller)
  await restore(page, controller, html)
  assert.deepEqual(await state(page), { checked: "true", state: "checked", thumb: "checked" })
  await recordChanges(page)
  await page.click(control)
  assert.equal((await state(page)).checked, "false")
  assert.deepEqual(await changes(page), [{ checked: false }])
})
