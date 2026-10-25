import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, reconnect, settle } from "./support.mjs"

// A checkbox controller that disconnects and connects again (a moved element) keeps its bubble input and its state. No Turbo here.

browserTest("checkbox: disconnecting and reconnecting keeps the bubble input's name, required and form", async ({ open }) => {
  const page = await open("form__bubble-input__value-required-disabled", "checkbox")
  const read = () => page.evaluate(() => {
    const control = document.querySelector('[data-controller~="chadcn--checkbox"]')
    const input = control.nextElementSibling
    return { tag: input?.tagName, name: input?.name, required: input?.required, form: input?.getAttribute("form"), value: input?.getAttribute("value"), inputs: document.querySelectorAll("input[aria-hidden=true]").length }
  })
  const before = await read()
  assert.equal(before.tag, "INPUT")
  assert.ok(before.name, "precondition: the input is named")

  await reconnect(page, "chadcn--checkbox", { anchor: "bubble-input" })
  await settle(page)
  assert.deepEqual(await read(), before)
})

browserTest("checkbox: a checked checkbox can be unchecked after a reconnect", async ({ open }) => {
  const page = await open("form__bubble-input", "checkbox")
  const errors = consoleErrors(page)
  const box = page.locator(host("chadcn--checkbox")).first()
  await box.click()
  await settle(page)
  assert.equal(await box.getAttribute("data-state"), "checked")
  await reconnect(page, "chadcn--checkbox")
  await box.click()
  await settle(page)
  assert.equal(await box.getAttribute("data-state"), "unchecked")
  assert.deepEqual(errors, [])
})
