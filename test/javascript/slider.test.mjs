import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, reconnect, settle } from "./support.mjs"

// chadcn--slider against its parity pages (spec: dev/port/specs/slider.md): keyboard steps, a pointer press on the track, the state
// attributes (aria-valuenow, the range and thumb offsets), the value-change / value-commit events, the disabled and controlled modes,
// form participation through the form_bubble_input primitive (bubble input value, bubbling `input` event, removal outside a form,
// form reset), and a reconnect that adopts the same inputs and keeps one set of listeners.

browserTest.component = "slider"

const thumb = "[data-slot=slider-thumb]"

const recordValues = (page) => page.evaluate(() => {
  window.__slider = []
  for (const name of ["value-change", "value-commit"]) {
    document.addEventListener(`chadcn--slider:${name}`, (event) => window.__slider.push(`${name}:${event.detail.value.join(",")}`))
  }
  window.__inputs = []
  document.addEventListener("input", (event) => window.__inputs.push(`${event.target.name}=${event.target.value}`))
})
const sliderEvents = (page) => page.evaluate(() => window.__slider)
const inputEvents = (page) => page.evaluate(() => window.__inputs)

const state = (page) => page.evaluate(() => {
  const root = document.querySelector("[data-slot=slider]")
  const range = root.querySelector("[data-slot=slider-range]")
  return {
    values: [...root.querySelectorAll("[data-slot=slider-thumb]")].map((el) => el.getAttribute("aria-valuenow")),
    range: [range.style.left, range.style.right],
    inputs: [...root.querySelectorAll("input")].map((input) => `${input.name}=${input.value}:${input.getAttribute("value")}`)
  }
})

browserTest("slider: arrows, PageUp and Home/End step the focused thumb and update aria-valuenow and the range", async ({ open }) => {
  const page = await open("keyboard__arrow-right-left")
  await recordValues(page)
  await page.focus(thumb)
  await page.keyboard.press("ArrowRight")
  assert.deepEqual((await state(page)).values, ["51"])
  await page.keyboard.press("ArrowLeft")
  await page.keyboard.press("ArrowLeft")
  await page.keyboard.press("PageUp")
  assert.deepEqual(await state(page), { values: ["59"], range: ["0%", "41%"], inputs: [] }, "outside a form there is no bubble input")
  await page.keyboard.press("End")
  await page.keyboard.press("Home")
  assert.deepEqual((await state(page)).values, ["0"])
  assert.deepEqual(await sliderEvents(page), [
    "value-commit:51", "value-change:51", "value-commit:50", "value-change:50", "value-commit:49", "value-change:49",
    "value-commit:59", "value-change:59", "value-commit:100", "value-change:100", "value-commit:0", "value-change:0"
  ])
})

browserTest("slider: a press on the track moves the closest thumb there and commits on release", async ({ open }) => {
  const page = await open("keyboard__arrow-right-left")
  await recordValues(page)
  const box = await page.locator("[data-slot=slider]").boundingBox()
  await page.mouse.click(box.x + box.width * 0.75, box.y + box.height / 2)
  assert.deepEqual((await state(page)).values, ["75"])
  assert.deepEqual(await sliderEvents(page), ["value-change:75", "value-commit:75"])
  assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "slider-thumb", "the moved thumb takes the focus")
})

browserTest("slider: a disabled slider ignores keys and track presses", async ({ open }) => {
  const page = await open("disabled__keys-ignored")
  await recordValues(page)
  const before = await state(page)
  await page.locator(thumb).first().evaluate((el) => el.focus())
  await page.keyboard.press("ArrowRight")
  const box = await page.locator("[data-slot=slider]").boundingBox()
  await page.mouse.click(box.x + box.width * 0.9, box.y + box.height / 2)
  assert.deepEqual(await state(page), before)
  assert.deepEqual(await sliderEvents(page), [])
})

browserTest("slider: a controlled slider dispatches value-change and keeps the server DOM", async ({ open }) => {
  const page = await open("controlled__value-stays-on-keys")
  await recordValues(page)
  const before = await state(page)
  await page.focus(thumb)
  await page.keyboard.press("ArrowRight")
  assert.deepEqual(await state(page), before)
  assert.equal((await sliderEvents(page)).filter((entry) => entry.startsWith("value-change")).length, 1)
})

browserTest("slider: inside a form the bubble input follows the value and dispatches a bubbling input event", async ({ open }) => {
  const page = await open("form__bubble-input")
  await recordValues(page)
  assert.deepEqual((await state(page)).inputs, ["volume=50:50"])
  await page.focus(thumb)
  await page.keyboard.press("ArrowRight")
  assert.deepEqual((await state(page)).inputs, ["volume=51:51"])
  assert.deepEqual(await inputEvents(page), ["volume=51"])
  assert.deepEqual(await page.evaluate(() => [...new FormData(document.getElementById("f1"))]), [["volume", "51"]])
})

browserTest("slider: a range inside a form submits name[] once per thumb and only the moved input fires", async ({ open }) => {
  const page = await open("form__bubble-input-range")
  await recordValues(page)
  await page.locator(thumb).nth(1).focus()
  await page.keyboard.press("ArrowLeft")
  assert.deepEqual((await state(page)).inputs, ["price[]=20:20", "price[]=79:79"])
  assert.deepEqual(await inputEvents(page), ["price[]=79"])
})

browserTest("slider: the form attribute keeps the input outside a form; a name without a form renders none", async ({ open }) => {
  const page = await open("form__form-attr-outside-form")
  assert.deepEqual((await state(page)).inputs, ["ext=30:30"])
  assert.deepEqual(await page.evaluate(() => [...new FormData(document.getElementById("f-ext"))]), [["ext", "30"]])
  const loose = await open("form__name-outside-form-no-input")
  assert.deepEqual((await state(loose)).inputs, [])
})

browserTest("slider: a form reset restores the first rendered value through the change path", async ({ open }) => {
  const page = await open("form__reset")
  await page.focus(thumb)
  await page.keyboard.press("End")
  await recordValues(page)
  await page.click("button[type=reset]")
  assert.deepEqual(await state(page), { values: ["50"], range: ["0%", "50%"], inputs: ["volume=50:50"] })
  assert.deepEqual(await sliderEvents(page), ["value-change:50"])
  assert.deepEqual(await inputEvents(page), ["volume=50"])
})

browserTest("slider: a reconnect inside a form adopts the same inputs and keeps one key and one reset listener", async ({ open }) => {
  const page = await open("form__reset")
  const errors = consoleErrors(page)
  await page.evaluate(() => { window.__input = document.querySelector("[data-slot=slider] input") })
  await reconnect(page, "chadcn--slider")
  await settle(page)
  assert.equal(await page.evaluate(() => document.querySelector("[data-slot=slider] input") === window.__input), true, "same input adopted")
  await recordValues(page)
  await page.focus(thumb)
  await page.keyboard.press("ArrowRight")
  assert.deepEqual(await sliderEvents(page), ["value-commit:51", "value-change:51"])
  await page.click("button[type=reset]")
  assert.deepEqual(await sliderEvents(page), ["value-commit:51", "value-change:51", "value-change:50"])
  assert.deepEqual(await inputEvents(page), ["volume=51", "volume=50"])
  assert.deepEqual(errors, [])
})
