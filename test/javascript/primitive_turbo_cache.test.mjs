import { assert, primitiveTest } from "./primitives_support.mjs";

// turbo_cache: the one Turbo-cache restore scaffold the controllers share (stimulus R3, radix-stimulus R2). The ticks are real
// zero-delay timers inside the page: a tick awaited after the event runs after the timer the primitive armed on that event, so
// the count of ticks until the restore is exact.

primitiveTest("turbo_cache: teardown runs synchronously on turbo:before-cache and restore runs SNAPSHOT_TICKS ticks later with its state", async (page) => {
  const result = await page.evaluate(async () => {
    const { turboCacheRestore, SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache");
    const log = [];
    const cache = turboCacheRestore({
      teardown: (info) => { log.push(["teardown", info]); return "state-from-teardown" },
      restore: (state) => log.push(["restore", state, cache.pending]),
    });
    const idle = cache.pending;
    document.dispatchEvent(new Event("turbo:before-cache"));
    const afterEvent = { pending: cache.pending, log: [...log] };
    const perTick = [];
    for (let count = 1; count <= SNAPSHOT_TICKS; count++) {
      await new Promise((resolve) => setTimeout(resolve, 0));
      perTick.push({ pending: cache.pending, restored: log.length === 2 });
    }
    cache.release();
    return { SNAPSHOT_TICKS, idle, afterEvent, perTick, log };
  });
  assert.equal(result.SNAPSHOT_TICKS, 2);
  assert.equal(result.idle, false);
  assert.deepEqual(result.afterEvent, { pending: true, log: [["teardown", { pending: false, state: undefined }]] });
  assert.deepEqual(result.perTick, [{ pending: true, restored: false }, { pending: false, restored: true }]);
  assert.deepEqual(result.log[1], ["restore", "state-from-teardown", false]);
});

primitiveTest("turbo_cache: release() drops a pending restore and stops listening", async (page) => {
  const result = await page.evaluate(async () => {
    const { turboCacheRestore } = await import("chadcn/primitives/turbo_cache");
    let teardowns = 0;
    let restores = 0;
    const cache = turboCacheRestore({ teardown: () => teardowns++, restore: () => restores++ });
    document.dispatchEvent(new Event("turbo:before-cache"));
    cache.release();
    const afterRelease = cache.pending;
    for (let count = 0; count < 4; count++) await new Promise((resolve) => setTimeout(resolve, 0));
    document.dispatchEvent(new Event("turbo:before-cache"));
    for (let count = 0; count < 4; count++) await new Promise((resolve) => setTimeout(resolve, 0));
    cache.release(); // idempotent
    return { teardowns, restores, afterRelease, pending: cache.pending };
  });
  assert.deepEqual(result, { teardowns: 1, restores: 0, afterRelease: false, pending: false });
});

primitiveTest("turbo_cache: a second before-cache inside the window hands the pending state to teardown and restores once", async (page) => {
  const result = await page.evaluate(async () => {
    const { turboCacheRestore, SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache");
    const log = [];
    let open = true;
    const cache = turboCacheRestore({
      teardown: ({ pending, state }) => { const wasOpen = open || (pending && state); open = false; log.push(["teardown", { pending, state }]); return wasOpen },
      restore: (wasOpen) => log.push(["restore", wasOpen]),
    });
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve, 0));
    document.dispatchEvent(new Event("turbo:before-cache")); // one tick in: the first restore has not run yet
    const afterSecond = { pending: cache.pending, log: [...log] };
    for (let count = 0; count < SNAPSHOT_TICKS + 2; count++) await new Promise((resolve) => setTimeout(resolve, 0));
    cache.release();
    return { afterSecond, log };
  });
  assert.deepEqual(result.afterSecond.log, [["teardown", { pending: false, state: undefined }], ["teardown", { pending: true, state: true }]]);
  assert.equal(result.afterSecond.pending, true);
  assert.deepEqual(result.log.slice(2), [["restore", true]]);
});

primitiveTest("turbo_cache: two owners on one page keep separate listeners, states and timers", async (page) => {
  const result = await page.evaluate(async () => {
    const { turboCacheRestore } = await import("chadcn/primitives/turbo_cache");
    const log = [];
    const first = turboCacheRestore({ teardown: () => "first", restore: (state) => log.push(state) });
    const second = turboCacheRestore({ teardown: () => "second", restore: (state) => log.push(state) });
    document.dispatchEvent(new Event("turbo:before-cache"));
    second.release();
    for (let count = 0; count < 4; count++) await new Promise((resolve) => setTimeout(resolve, 0));
    first.release();
    return log;
  });
  assert.deepEqual(result, ["first"]);
});
