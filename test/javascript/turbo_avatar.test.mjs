import { browserTest } from "./harness.mjs"
import { assert, consoleErrors, reconnect, settle } from "./support.mjs"
import { afterSnapshotTicks, countIn, restore, snapshot } from "./turbo_support.mjs"

// Turbo page cache for the avatar: the image mounts from its template once it has loaded (stimulus R2/R3, radix-stimulus R10).
// The fallback reconnect test needs no snapshot, but it guards the same template mount, so it stays with the avatar.

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
  await reconnect(page, "chadcn--avatar")
  await page.waitForSelector("[data-slot=avatar-image]")
  await afterSnapshotTicks(page) // a late duplicate mount would land inside these ticks
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
