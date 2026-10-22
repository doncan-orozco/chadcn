import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// Turbo page cache for the disclosure, scroll and form controllers (stimulus R2/R3, radix-stimulus R10). The snapshot is taken
// one timer tick after turbo:before-cache, so the markup must be restorable by then; the restore is simulated by re-inserting the
// host as it is in that snapshot, which connects a new controller (the same approach as turbo_overlays.test.mjs).
const host = (controller) => `[data-controller~="${controller}"]`

const snapshot = (page, controller) => page.evaluate(async (selector) => {
  document.dispatchEvent(new Event("turbo:before-cache"))
  await new Promise((resolve) => setTimeout(resolve))
  return document.querySelector(selector).outerHTML
}, host(controller))

const restore = async (page, controller, html) => {
  await page.evaluate(({ selector, html }) => {
    const live = document.querySelector(selector)
    live.insertAdjacentHTML("afterend", html)
    live.remove()
  }, { selector: host(controller), html })
  await settle(page)
}

// Counts matches in the snapshot markup without connecting anything (<template> content is not queried, as in the DOM).
const countIn = (page, html, selector) => page.evaluate(({ html, selector }) => {
  const root = document.createElement("div")
  root.innerHTML = html
  return root.querySelectorAll(selector).length
}, { html, selector })

// Turbo keeps the page for a visit to #hash: after the snapshot the live page must work again without a restore.
const afterSnapshotTicks = (page) => page.evaluate(async () => { for (let tick = 0; tick < 4; tick++) await new Promise((resolve) => setTimeout(resolve)) })

browserTest("accordion: a closed item keeps its body in the snapshot and opens after the restore", async ({ open }) => {
  const page = await open("single__all-closed", "accordion")
  const html = await snapshot(page, "chadcn--accordion")
  assert.ok(await countIn(page, html, "template") >= 1, "the closed bodies are in the snapshot")

  await restore(page, "chadcn--accordion", html)
  const trigger = page.locator("[data-chadcn--accordion-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  assert.equal(await trigger.getAttribute("aria-expanded"), "true")
  assert.ok(await page.locator("[data-chadcn--accordion-target~=content]").first().evaluate((el) => el.childElementCount) > 0, "content is mounted")
  assert.equal(await page.locator("[data-chadcn--accordion-target~=content] template").count(), 0)
})

browserTest("accordion: an open item keeps its content and state through the snapshot", async ({ open }) => {
  const page = await open("single__default-value-open", "accordion")
  const before = await page.locator("[data-chadcn--accordion-target~=item][data-state=open]").count()
  assert.ok(before > 0, "precondition: an item is open")
  const html = await snapshot(page, "chadcn--accordion")
  await restore(page, "chadcn--accordion", html)
  assert.equal(await page.locator("[data-chadcn--accordion-target~=item][data-state=open]").count(), before)
  assert.ok(await page.locator("[data-chadcn--accordion-target~=item][data-state=open] [data-chadcn--accordion-target~=content]").first().evaluate((el) => el.childElementCount) > 0)
})

browserTest("accordion: the live page still opens items after a snapshot that is not followed by a navigation", async ({ open }) => {
  const page = await open("single__all-closed", "accordion")
  await snapshot(page, "chadcn--accordion")
  await afterSnapshotTicks(page)
  const trigger = page.locator("[data-chadcn--accordion-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  assert.equal(await trigger.getAttribute("aria-expanded"), "true")
  assert.ok(await page.locator("[data-chadcn--accordion-target~=content]").first().evaluate((el) => el.childElementCount) > 0)
})

browserTest("collapsible: a closed content keeps its body in the snapshot and opens after the restore", async ({ open }) => {
  const page = await open("closed__rest", "collapsible")
  const html = await snapshot(page, "chadcn--collapsible")
  assert.ok(await countIn(page, html, "template") >= 1, "the closed body is in the snapshot")

  await restore(page, "chadcn--collapsible", html)
  const trigger = page.locator("[data-chadcn--collapsible-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  assert.equal(await trigger.getAttribute("aria-expanded"), "true")
  assert.ok(await page.locator("[data-chadcn--collapsible-target~=content]").first().evaluate((el) => el.childElementCount) > 0, "content is mounted")
})

browserTest("collapsible: an open content survives the snapshot and can be closed and reopened", async ({ open }) => {
  const page = await open("default-open__rest", "collapsible")
  const html = await snapshot(page, "chadcn--collapsible")
  await restore(page, "chadcn--collapsible", html)
  const content = page.locator("[data-chadcn--collapsible-target~=content]").first()
  assert.equal(await content.getAttribute("data-state"), "open")
  assert.ok(await content.evaluate((el) => el.childElementCount) > 0)
  const trigger = page.locator("[data-chadcn--collapsible-target~=trigger]").first()
  await trigger.click()
  await settle(page)
  await trigger.click()
  await settle(page)
  assert.ok(await content.evaluate((el) => el.childElementCount) > 0, "reopened content is mounted again")
})

browserTest("tabs: an inactive panel keeps its body in the snapshot and shows it after the restore", async ({ open }) => {
  const page = await open("default", "tabs")
  const html = await snapshot(page, "chadcn--tabs")
  assert.ok(await countIn(page, html, "template") >= 1, "the inactive bodies are in the snapshot")

  await restore(page, "chadcn--tabs", html)
  const triggers = page.locator("[role=tab]")
  assert.ok(await triggers.count() > 1, "precondition: two tabs")
  await triggers.nth(1).click()
  await settle(page)
  assert.equal(await triggers.nth(1).getAttribute("aria-selected"), "true")
  const panel = page.locator("[role=tabpanel][data-state=active]")
  assert.equal(await panel.count(), 1)
  assert.ok(await panel.evaluate((el) => el.childElementCount > 0 || el.textContent.trim() !== ""), "the activated panel has its body")
})

// Stimulus reports an error raised in connect() with console.error, not as a page error.
const consoleErrors = (page) => {
  const errors = []
  page.on("console", (message) => { if (message.type() === "error") errors.push(message.text()) })
  return errors
}

browserTest("avatar: a loaded image does not raise after the snapshot, the restore shows one image", async ({ open }) => {
  const page = await open("size-default__image-loaded", "avatar")
  await page.waitForSelector("[data-slot=avatar-image]")
  const errors = consoleErrors(page)
  const html = await snapshot(page, "chadcn--avatar")
  assert.equal(await countIn(page, html, "[data-slot=avatar-image]"), 0, "the snapshot holds the image only as its template")

  await restore(page, "chadcn--avatar", html)
  await page.waitForSelector("[data-slot=avatar-image]")
  assert.equal(await page.locator("[data-slot=avatar-image]").count(), 1)
  await afterSnapshotTicks(page)
  assert.deepEqual(errors, [])
})

browserTest("avatar: a fallback survives a reconnect after the image loaded", async ({ open }) => {
  const page = await open("size-default__image-loaded", "avatar")
  await page.waitForSelector("[data-slot=avatar-image]")
  const errors = consoleErrors(page)
  await page.evaluate(async () => {
    const root = document.querySelector('[data-controller~="chadcn--avatar"]')
    const parent = root.parentNode
    const next = root.nextSibling
    root.remove()
    await new Promise((resolve) => setTimeout(resolve))
    parent.insertBefore(root, next)
    await new Promise((resolve) => setTimeout(resolve, 100))
  })
  await settle(page)
  assert.deepEqual(errors, [])
  assert.equal(await page.locator("[data-slot=avatar-image]").count(), 1)
})

browserTest("avatar: the live page keeps its image after a snapshot that is not followed by a navigation", async ({ open }) => {
  const page = await open("size-default__image-loaded", "avatar")
  await page.waitForSelector("[data-slot=avatar-image]")
  await snapshot(page, "chadcn--avatar")
  await afterSnapshotTicks(page)
  await page.waitForSelector("[data-slot=avatar-image]")
  assert.equal(await page.locator("[data-slot=avatar-image]").count(), 1)
})

const SCROLLBAR = "[data-slot=scroll-area-scrollbar]"

browserTest("scroll-area: the snapshot has no mounted scrollbar and the restore does not duplicate them", async ({ open }) => {
  const page = await open("default__hover", "scroll-area")
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  assert.equal(await page.locator(SCROLLBAR).count(), 1, "precondition: one scrollbar while hovered")

  const html = await snapshot(page, "chadcn--scroll-area")
  assert.equal(await countIn(page, html, SCROLLBAR), 0, "no mounted scrollbar in the snapshot")

  await restore(page, "chadcn--scroll-area", html)
  assert.equal(await page.locator(SCROLLBAR).count(), 0)
  await page.mouse.move(0, 0)
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  await settle(page)
  assert.equal(await page.locator(SCROLLBAR).count(), 1, "exactly one scrollbar after the restore")
})

browserTest("scroll-area: the live page shows its scrollbar again after a snapshot that is not followed by a navigation", async ({ open }) => {
  const page = await open("default__hover", "scroll-area")
  await snapshot(page, "chadcn--scroll-area")
  await afterSnapshotTicks(page)
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  assert.equal(await page.locator(SCROLLBAR).count(), 1)
})

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

  await page.evaluate(async () => {
    const control = document.querySelector('[data-controller~="chadcn--checkbox"]')
    const parent = control.parentNode
    const input = control.nextElementSibling
    const after = input?.nextSibling ?? null
    control.remove() // Stimulus disconnects on the mutation observer microtask
    await new Promise((resolve) => setTimeout(resolve))
    parent.insertBefore(control, input?.isConnected ? input : after)
    await new Promise((resolve) => setTimeout(resolve))
  })
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
  await page.evaluate(async () => {
    const control = document.querySelector('[data-controller~="chadcn--checkbox"]')
    const parent = control.parentNode
    const next = control.nextSibling
    control.remove()
    await new Promise((resolve) => setTimeout(resolve))
    parent.insertBefore(control, next)
    await new Promise((resolve) => setTimeout(resolve))
  })
  await box.click()
  await settle(page)
  assert.equal(await box.getAttribute("data-state"), "unchecked")
  assert.deepEqual(errors, [])
})

browserTest("scroll-area: a hovered root keeps its scrollbar through a snapshot that is not followed by a navigation", async ({ open }) => {
  const page = await open("default__hover", "scroll-area")
  await page.locator(host("chadcn--scroll-area")).first().hover()
  await page.waitForSelector(SCROLLBAR)
  await snapshot(page, "chadcn--scroll-area")
  await afterSnapshotTicks(page)
  await page.waitForSelector(SCROLLBAR) // no pointer move: the new controller learns about the pointer that is already inside
  await settle(page)
  assert.equal(await page.locator(SCROLLBAR).count(), 1)
})

// NO_MOTION is `*{animation:none!important}` (specificity 0,0,0): a more specific !important rule on the exit state wins, so the
// exit animation really runs and the controller is snapshotted mid-exit.
const holdExit = (page, selector) =>
  page.addStyleTag({ content: `@keyframes shadcn-test-hold{to{opacity:.5}} ${selector}{animation:shadcn-test-hold 60s!important}` })

// Every matching element in the snapshot is hidden and holds nothing but its body template.
const allRestored = (page, html, selector) => page.evaluate(({ html, selector }) => {
  const root = document.createElement("div")
  root.innerHTML = html
  const found = [...root.querySelectorAll(selector)]
  return found.length > 0 && found.every((el) => el.hidden && el.children.length === 1 && el.firstElementChild.tagName === "TEMPLATE")
}, { html, selector })

browserTest("accordion: an item snapshotted mid exit animation is closed, hidden and keeps its body", async ({ open }) => {
  const page = await open("single__collapsible__default-value-open", "accordion")
  const closed = "[data-chadcn--accordion-target~=content][data-state=closed]"
  await holdExit(page, closed)
  const handle = await page.locator("[data-chadcn--accordion-target~=item][data-state=open] [data-chadcn--accordion-target~=content]").first().elementHandle()
  await page.locator("[data-chadcn--accordion-target~=item][data-state=open] [data-chadcn--accordion-target~=trigger]").first().click()
  assert.ok(await handle.evaluate((el) => el.dataset.state === "closed" && !el.hidden && el.childElementCount > 0), "precondition: exit running")
  const html = await snapshot(page, "chadcn--accordion")
  assert.ok(await allRestored(page, html, closed))
  await afterSnapshotTicks(page)
  assert.equal(await handle.evaluate((el) => el.hidden), true, "the live page does not keep the exiting content visible")
})

browserTest("collapsible: a content snapshotted mid exit animation is closed, hidden and keeps its body", async ({ open }) => {
  const page = await open("default-open__rest", "collapsible")
  const closed = "[data-chadcn--collapsible-target~=content][data-state=closed]"
  await holdExit(page, closed)
  const content = page.locator("[data-chadcn--collapsible-target~=content]").first()
  await page.locator("[data-chadcn--collapsible-target~=trigger]").first().click()
  assert.ok(await content.evaluate((el) => !el.hidden && el.childElementCount > 0), "precondition: exit running")
  const html = await snapshot(page, "chadcn--collapsible")
  assert.ok(await allRestored(page, html, closed))
  await afterSnapshotTicks(page)
  assert.equal(await content.evaluate((el) => el.hidden), true)
})

browserTest("tabs: a panel snapshotted mid exit animation is inactive, hidden and keeps its body", async ({ open }) => {
  const page = await open("default", "tabs")
  const inactive = "[role=tabpanel][data-state=inactive]"
  await holdExit(page, inactive)
  const leaving = await page.locator("[role=tabpanel][data-state=active]").first().elementHandle()
  await page.locator("[role=tab]").nth(1).click()
  assert.ok(await leaving.evaluate((el) => el.dataset.state === "inactive" && !el.hidden), "precondition: exit running")
  const html = await snapshot(page, "chadcn--tabs")
  assert.ok(await allRestored(page, html, inactive))
  await afterSnapshotTicks(page)
  assert.equal(await leaving.evaluate((el) => el.hidden), true)
})
