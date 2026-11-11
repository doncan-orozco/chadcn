import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, reconnect, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// chadcn--toggle against its parity pages (spec: dev/port/specs/toggle.md): pointer and keyboard (the native button turns Space and
// Enter into a click), aria-pressed and data-state, the pressed-change event, controlled mode, the disabled value, form participation
// (type=button never submits), a reconnect and a Turbo cache restore of the state the user chose.

browserTest.component = "toggle"

const toggle = "[data-slot=toggle]"

// Every pressed-change dispatched, in order, with how it travels.
const recordPressed = (page) => page.evaluate(() => {
  window.__pressed = []
  document.addEventListener("chadcn--toggle:pressed-change", (event) => window.__pressed.push({ pressed: event.detail.pressed, bubbles: event.bubbles }))
})
const pressedChanges = (page) => page.evaluate(() => window.__pressed.map((entry) => entry.pressed))

const state = (page) => page.locator(toggle).first().evaluate((el) => ({ pressed: el.getAttribute("aria-pressed"), state: el.dataset.state }))
const ON = { pressed: "true", state: "on" }
const OFF = { pressed: "false", state: "off" }

browserTest("toggle: a click flips aria-pressed and data-state and dispatches a bubbling pressed-change", async ({ open }) => {
  const page = await open("default")
  await recordPressed(page)
  assert.deepEqual(await state(page), OFF)
  await page.click(toggle)
  assert.deepEqual(await state(page), ON)
  await page.click(toggle)
  assert.deepEqual(await state(page), OFF)
  assert.deepEqual(await page.evaluate(() => window.__pressed), [{ pressed: true, bubbles: true }, { pressed: false, bubbles: true }])
})

browserTest("toggle: Space and Enter on the focused toggle flip it", async ({ open }) => {
  const page = await open("default")
  await recordPressed(page)
  await page.focus(toggle)
  await page.keyboard.press("Space")
  assert.deepEqual(await state(page), ON)
  await page.keyboard.press("Enter")
  assert.deepEqual(await state(page), OFF)
  assert.deepEqual(await pressedChanges(page), [true, false])
})

browserTest("toggle: a default-pressed toggle starts on and turns off", async ({ open }) => {
  const page = await open("default-pressed__click__on-off")
  await recordPressed(page)
  assert.deepEqual(await state(page), ON)
  await page.click(toggle)
  assert.deepEqual(await state(page), OFF)
  assert.deepEqual(await pressedChanges(page), [false])
})

browserTest("toggle: a controlled toggle only dispatches the requested state and leaves the DOM to the server", async ({ open }) => {
  const page = await open("controlled__pressed-true__click-stays")
  await recordPressed(page)
  await page.click(toggle)
  await page.click(toggle)
  assert.deepEqual(await state(page), ON)
  assert.deepEqual(await pressedChanges(page), [false, false], "every request asks for the opposite of the rendered state")
})

browserTest("toggle: a click the caller prevented does not toggle", async ({ open }) => {
  const page = await open("default")
  await recordPressed(page)
  await page.evaluate(() => document.addEventListener("click", (event) => event.preventDefault(), { capture: true }))
  await page.click(toggle)
  assert.deepEqual(await state(page), OFF)
  assert.deepEqual(await pressedChanges(page), [])
})

// A native disabled button receives no click at all; the controller's own disabled value is what guards a toggle whose `disabled`
// attribute was taken away (by a caller script) while the server still renders it disabled.
browserTest("toggle: the disabled value ignores a click that reaches the button", async ({ open }) => {
  const page = await open("disabled__off")
  await recordPressed(page)
  assert.equal(await page.locator(toggle).isDisabled(), true, "precondition: rendered disabled")
  await page.locator(toggle).evaluate((el) => el.removeAttribute("disabled"))
  await page.click(toggle)
  assert.deepEqual(await state(page), OFF)
  assert.deepEqual(await pressedChanges(page), [])
})

browserTest("toggle: inside a form a click and Enter toggle without submitting it", async ({ open }) => {
  const page = await open("api__inside-form-does-not-submit")
  await page.evaluate(() => {
    window.__submits = 0
    document.querySelector("form").addEventListener("submit", (event) => { event.preventDefault(); window.__submits++ })
  })
  await page.click(toggle)
  await page.focus(toggle)
  await page.keyboard.press("Enter")
  await settle(page)
  assert.deepEqual(await state(page), OFF, "toggled twice")
  assert.equal(await page.evaluate(() => window.__submits), 0)
})

browserTest("toggle: a reconnected toggle reads its state from the DOM and dispatches once per click", async ({ open }) => {
  const page = await open("default")
  const errors = consoleErrors(page)
  await page.click(toggle)
  await reconnect(page, "chadcn--toggle")
  await recordPressed(page)
  await page.click(toggle)
  assert.deepEqual(await state(page), OFF)
  assert.deepEqual(await pressedChanges(page), [false])
  assert.deepEqual(errors, [])
})

browserTest("toggle: the state a user chose survives a Turbo cache snapshot and restore", async ({ open }) => {
  const page = await open("default")
  await page.click(toggle)
  const html = await snapshot(page, "chadcn--toggle")
  await restore(page, "chadcn--toggle", html)
  assert.deepEqual(await state(page), ON)
  await recordPressed(page)
  await page.click(toggle)
  assert.deepEqual(await state(page), OFF)
  assert.deepEqual(await pressedChanges(page), [false])
})
