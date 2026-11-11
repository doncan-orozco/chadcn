import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, host, reconnect, settle } from "./support.mjs"

// chadcn--avatar against its parity pages (spec: dev/port/specs/avatar.md): which parts are mounted for each loading status, in the
// caller's order, the delayed fallback, the loading-status-change event and the server markup put back on disconnect. The Turbo
// page cache cases live in turbo_avatar.test.mjs.

browserTest.component = "avatar"

const controller = "chadcn--avatar"

// The children of the avatar root as a reader of the DOM sees them: a mounted part by its data-slot, a placeholder by its target.
const parts = (page) => page.evaluate((selector) => [...document.querySelector(selector).children].map((el) =>
  el.tagName === "TEMPLATE" ? `template:${el.getAttribute("data-chadcn--avatar-target")}` : el.dataset.slot
), host(controller))

// Collects the loading statuses the root reports from now on.
const recordStatuses = (page) => page.evaluate(() => {
  window.__statuses = []
  document.addEventListener("chadcn--avatar:loading-status-change", (event) => window.__statuses.push(event.detail.status))
})
const statuses = (page) => page.evaluate(() => window.__statuses)

browserTest("avatar: a loaded image mounts right after its template and unmounts the fallback into a template at its place", async ({ open }) => {
  const page = await open("size-default__image-loaded")
  await page.waitForSelector("[data-slot=avatar-image]")
  await settle(page)
  assert.deepEqual(await parts(page), ["template:image", "avatar-image", "template:fallback"])
  const image = page.locator("[data-slot=avatar-image]")
  assert.equal(await image.getAttribute("alt"), "@shadcn")
  assert.equal(await page.locator("template[data-chadcn--avatar-target=fallback]").evaluate((el) => el.content.firstElementChild?.dataset.slot), "avatar-fallback")
})

browserTest("avatar: the caller's order is kept when the fallback comes before the image", async ({ open }) => {
  const page = await open("image__fallback-before-image")
  await page.waitForSelector("[data-slot=avatar-image]")
  await settle(page)
  assert.deepEqual(await parts(page), ["template:fallback", "template:image", "avatar-image"])
})

browserTest("avatar: an image that fails or has no src never mounts, the fallback stays", async ({ open }) => {
  for (const scenario of ["size-default__image-error", "image__no-src"]) {
    const page = await open(scenario)
    await recordStatuses(page)
    await reconnect(page, controller)
    await page.waitForFunction(() => window.__statuses.at(-1) === "error")
    await settle(page)
    assert.deepEqual(await parts(page), ["template:image", "avatar-fallback"], scenario)
  }
})

browserTest("avatar: loading-status-change reports the status as it changes and ends on loaded", async ({ open }) => {
  const page = await open("size-default__image-loaded")
  await page.waitForSelector("[data-slot=avatar-image]")
  await recordStatuses(page)
  await reconnect(page, controller)
  await page.waitForFunction(() => window.__statuses.at(-1) === "loaded")
  const seen = await statuses(page)
  assert.ok(seen.every((status) => ["loading", "loaded"].includes(status)), JSON.stringify(seen))
  assert.equal(new Set(seen).size, seen.length, "a status is reported once per change")
})

browserTest("avatar: a delayed fallback waits in its template, then mounts in its place", async ({ open }) => {
  const page = await open("fallback-delay__no-image")
  await settle(page)
  assert.deepEqual(await parts(page), ["template:fallback"], "the fallback is not mounted before its delay")

  // The delay is shortened on the server template and the controller reconnected: the test waits on ticks, never on the clock.
  await page.evaluate(() => document.querySelector("template[data-chadcn--avatar-target=fallback]").setAttribute("data-chadcn--avatar-delay-ms", "0"))
  await reconnect(page, controller)
  await page.waitForSelector("[data-slot=avatar-fallback]")
  assert.deepEqual(await parts(page), ["avatar-fallback"], "the template is replaced by the fallback")
})

browserTest("avatar: disconnect puts the server markup back (image as its template, fallback in place)", async ({ open }) => {
  const page = await open("size-default__image-loaded")
  await page.waitForSelector("[data-slot=avatar-image]")
  const errors = consoleErrors(page)
  const detached = await page.evaluate(async (selector) => {
    const root = document.querySelector(selector)
    root.remove()
    await new Promise((resolve) => setTimeout(resolve))
    return [...root.children].map((el) => el.tagName === "TEMPLATE" ? `template:${el.getAttribute("data-chadcn--avatar-target")}` : el.dataset.slot)
  }, host(controller))
  assert.deepEqual(detached, ["template:image", "avatar-fallback"])
  assert.deepEqual(errors, [])
})
