import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, settle } from "./support.mjs"
import { restore, snapshot } from "./turbo_support.mjs"

// chadcn--tabs against its parity pages (spec: dev/port/specs/tabs.md): pointer (mousedown) and keyboard selection, automatic and
// manual activation, the roving tab stop, trigger and panel state, the value-change event, controlled mode, disconnect cleanup and a
// Turbo cache restore of the tab the user chose. The core Turbo snapshot cases (inactive bodies kept, exit animation finished) live
// in turbo_disclosure.test.mjs.

browserTest.component = "tabs"

const tab = (page, name) => page.getByRole("tab", { name })
const focused = (page) => page.evaluate(() => document.activeElement?.textContent.trim())
// The roving primitive moves focus in a zero-delay timeout, like Radix: let it run before reading the focus.
const press = async (page, key) => { await page.keyboard.press(key); await settle(page) }

// Every value-change the root dispatches, in order.
const recordValues = (page) => page.evaluate(() => {
  window.__values = []
  document.addEventListener("chadcn--tabs:value-change", (event) => window.__values.push({ value: event.detail.value, cancelable: event.cancelable }))
})
const values = (page) => page.evaluate(() => window.__values.map((entry) => entry.value))

// The selected tab and the panels as a reader of the DOM sees them.
const selection = (page) => page.evaluate(() => ({
  selected: [...document.querySelectorAll("[role=tab]")].filter((el) => el.getAttribute("aria-selected") === "true").map((el) => el.textContent.trim()),
  active: [...document.querySelectorAll("[role=tab][data-state=active]")].map((el) => el.textContent.trim()),
  panels: [...document.querySelectorAll("[role=tabpanel]")].map((el) => ({
    state: el.dataset.state, hidden: el.hidden, body: el.hidden ? "" : el.textContent.trim(), labelledBy: document.getElementById(el.getAttribute("aria-labelledby"))?.textContent.trim()
  })).filter((panel) => !panel.hidden)
}))

const shows = (name, body) => ({ selected: [name], active: [name], panels: [{ state: "active", hidden: false, body, labelledBy: name }] })
const ACCOUNT = shows("Account", "Make changes to your account here.")
const PASSWORD = shows("Password", "Change your password here.")

browserTest("tabs: a primary press selects the tab, swaps the panels and dispatches a non-cancelable value-change", async ({ open }) => {
  const page = await open("default")
  await recordValues(page)
  assert.deepEqual(await selection(page), ACCOUNT)

  await tab(page, "Password").click()
  await settle(page)
  assert.deepEqual(await selection(page), PASSWORD)
  assert.equal(await page.locator("[role=tabpanel][data-state=inactive]:not([hidden])").count(), 0, "the inactive panels are hidden")
  assert.equal(await page.getByText("Make changes to your account here.").count(), 0, "the left panel's body is unmounted")
  assert.deepEqual(await page.evaluate(() => window.__values), [{ value: "password", cancelable: false }])
})

browserTest("tabs: pressing the active tab dispatches nothing", async ({ open }) => {
  const page = await open("default")
  await recordValues(page)
  await tab(page, "Account").click()
  await settle(page)
  assert.deepEqual(await selection(page), ACCOUNT)
  assert.deepEqual(await values(page), [])
})

browserTest("tabs: a secondary or ctrl press does not select", async ({ open }) => {
  const page = await open("default")
  await recordValues(page)
  await tab(page, "Password").click({ button: "right" })
  await tab(page, "Password").click({ modifiers: ["Control"] })
  await settle(page)
  assert.deepEqual(await selection(page), ACCOUNT)
  assert.deepEqual(await values(page), [])
})

browserTest("tabs: a press the caller prevented does not select", async ({ open }) => {
  const page = await open("default")
  await recordValues(page)
  await page.evaluate(() => document.addEventListener("mousedown", (event) => event.preventDefault(), { capture: true }))
  await tab(page, "Password").click()
  await settle(page)
  assert.deepEqual(await selection(page), ACCOUNT)
  assert.deepEqual(await values(page), [])
})

// Keyboard only: a mouse press leaves the roving group in click-focus mode, so the next Tab entry is not redirected (Radix's
// re-entry quirk, scenario click__reentry-quirk).
browserTest("tabs: Tab enters the list on the selected tab and Shift+Tab leaves it", async ({ open }) => {
  const page = await open("loop-false__stops-at-ends")
  await page.locator("#before").focus()
  await press(page, "Tab")
  assert.equal(await focused(page), "Account", "entry focus goes to the active tab")
  await press(page, "ArrowRight")
  await press(page, "Shift+Tab")
  assert.equal(await focused(page), "Before", "Shift+Tab leaves the list in one step")
  await press(page, "Tab")
  assert.equal(await focused(page), "Password", "the entry follows the selection")
})

browserTest("tabs: ArrowRight and ArrowLeft move and select in automatic mode, wrapping; Home and End jump", async ({ open }) => {
  const page = await open("default")
  await recordValues(page)
  await tab(page, "Account").focus()
  await press(page, "ArrowRight")
  assert.equal(await focused(page), "Password")
  assert.deepEqual(await selection(page), PASSWORD)
  await press(page, "ArrowLeft")
  await press(page, "ArrowLeft")
  assert.equal(await focused(page), "Settings", "ArrowLeft wraps to the last tab")
  await press(page, "Home")
  assert.equal(await focused(page), "Account")
  await press(page, "End")
  assert.equal(await focused(page), "Settings")
  assert.deepEqual(await values(page), ["password", "account", "settings", "account", "settings"])
})

browserTest("tabs: arrows skip a disabled tab", async ({ open }) => {
  const page = await open("trigger-disabled")
  assert.equal(await tab(page, "Password").isDisabled(), true, "precondition: Password is disabled")
  await tab(page, "Account").focus()
  await press(page, "ArrowRight")
  assert.equal(await focused(page), "Settings")
  assert.equal(await tab(page, "Password").getAttribute("aria-selected"), "false")
})

browserTest("tabs: with loop false the arrows stop at both ends", async ({ open }) => {
  const page = await open("loop-false__stops-at-ends")
  await tab(page, "Account").focus()
  await press(page, "ArrowLeft")
  assert.equal(await focused(page), "Account")
  await press(page, "End")
  await press(page, "ArrowRight")
  assert.equal(await focused(page), "Settings")
})

browserTest("tabs: a vertical list moves on ArrowDown and ArrowUp and ignores ArrowRight", async ({ open }) => {
  const page = await open("orientation-vertical")
  await tab(page, "Account").focus()
  await press(page, "ArrowRight")
  assert.equal(await focused(page), "Account")
  await press(page, "ArrowDown")
  assert.equal(await focused(page), "Password")
  await press(page, "ArrowUp")
  assert.equal(await focused(page), "Account")
})

browserTest("tabs: manual activation moves focus with the arrows and selects only on Enter or Space", async ({ open }) => {
  const page = await open("activation-manual")
  await recordValues(page)
  await tab(page, "Account").focus()
  await press(page, "ArrowRight")
  assert.equal(await focused(page), "Password")
  assert.deepEqual(await selection(page), ACCOUNT, "focus alone does not select")
  await press(page, "Enter")
  assert.deepEqual(await selection(page), PASSWORD)
  await press(page, "ArrowLeft")
  await press(page, "Space")
  assert.deepEqual(await selection(page), ACCOUNT)
  assert.deepEqual(await values(page), ["password", "account"])
})

browserTest("tabs: a controlled root only dispatches value-change and applies the value the server sets", async ({ open }) => {
  const page = await open("controlled-value")
  await recordValues(page)
  // No dedupe in controlled mode (spec: Controlled): the press focuses the inactive tab, whose focus activation requests the value,
  // then the press requests it again, so it is dispatched twice like Radix; a press on the focused tab requests it once.
  await tab(page, "Account").click()
  await settle(page)
  assert.deepEqual(await selection(page), PASSWORD, "the DOM stays as rendered")
  assert.deepEqual(await values(page), ["account", "account"])
  await tab(page, "Account").click()
  await settle(page)
  assert.deepEqual(await values(page), ["account", "account", "account"])

  await page.evaluate(() => document.querySelector("[data-slot=tabs]").setAttribute("data-chadcn--tabs-value-value", "account"))
  await settle(page)
  assert.deepEqual(await selection(page), ACCOUNT)
})

// The roving primitive listens on the list: removing the controller must take its keyboard handling away, and a new controller must
// not add a second one (two listeners would move focus two tabs per press).
browserTest("tabs: disconnect releases the roving focus and a reconnect adds exactly one", async ({ open }) => {
  const page = await open("activation-manual")
  const errors = consoleErrors(page)
  const swap = (value) => page.evaluate(async (value) => {
    document.querySelector("[data-slot=tabs]").setAttribute("data-controller", value)
    await new Promise((resolve) => setTimeout(resolve))
  }, value)

  await swap("")
  await tab(page, "Account").focus()
  await press(page, "ArrowRight")
  assert.equal(await focused(page), "Account", "no roving listener left after disconnect")

  await swap("chadcn--tabs")
  await press(page, "ArrowRight")
  assert.equal(await focused(page), "Password", "one step per press after the reconnect")
  assert.deepEqual(errors, [])
})

browserTest("tabs: the tab a user chose survives a Turbo cache snapshot and restore", async ({ open }) => {
  const page = await open("default")
  await tab(page, "Password").click()
  await settle(page)
  const html = await snapshot(page, "chadcn--tabs")
  await restore(page, "chadcn--tabs", html)
  assert.deepEqual(await selection(page), PASSWORD)

  await recordValues(page)
  await tab(page, "Password").click()
  await tab(page, "Account").click()
  await settle(page)
  assert.deepEqual(await selection(page), ACCOUNT)
  assert.deepEqual(await values(page), ["account"], "the restored controller knows Password was selected")
})
