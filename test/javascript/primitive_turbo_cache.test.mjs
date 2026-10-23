import { assert, primitiveTest } from "./primitives_support.mjs";

// turbo_cache: the one Turbo-cache restore scaffold the controllers share (stimulus R3, radix-stimulus R2). The ticks are real
// zero-delay timers inside the page: a tick awaited after the event runs after the timer the primitive armed on that event, so
// the count of ticks until the restore is exact. Real zero-delay ticks, not useFakeTimers: window.__clock.advance(0) drains
// nested timers and cannot count ticks, and the harness tick() helper is a separate page round trip, so dispatch, ticks and
// reads stay inside one evaluate.

primitiveTest("turbo_cache: teardown runs synchronously on turbo:before-cache and restore runs SNAPSHOT_TICKS ticks later with its state", async (page) => {
  const timeline = await page.evaluate(async () => {
    const { turboCacheRestore, SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache");
    const nextTick = () => new Promise((resolve) => setTimeout(resolve, 0));
    const log = [];
    const cache = turboCacheRestore({
      teardown: (cancelled) => { log.push(["teardown", cancelled]); return "state-from-teardown" },
      restore: (state) => log.push(["restore", state, cache.pending]),
    });
    const pendingBeforeEvent = cache.pending;
    document.dispatchEvent(new Event("turbo:before-cache"));
    const afterEvent = { pending: cache.pending, log: [...log] };
    const perTick = [];
    for (let tick = 1; tick <= SNAPSHOT_TICKS; tick++) {
      await nextTick();
      perTick.push({ pending: cache.pending, restored: log.length === 2 });
    }
    cache.release();
    return { SNAPSHOT_TICKS, pendingBeforeEvent, afterEvent, perTick, log };
  });
  assert.equal(timeline.SNAPSHOT_TICKS, 2);
  assert.equal(timeline.pendingBeforeEvent, false);
  assert.deepEqual(timeline.afterEvent, { pending: true, log: [["teardown", { pending: false, state: undefined }]] });
  assert.deepEqual(timeline.perTick, [{ pending: true, restored: false }, { pending: false, restored: true }]);
  assert.deepEqual(timeline.log[1], ["restore", "state-from-teardown", false]);
});

primitiveTest("turbo_cache: release() drops a pending restore and stops listening", async (page) => {
  const released = await page.evaluate(async () => {
    const { turboCacheRestore, SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache");
    const nextTick = () => new Promise((resolve) => setTimeout(resolve, 0));
    let teardowns = 0;
    let restores = 0;
    const cache = turboCacheRestore({ teardown: () => teardowns++, restore: () => restores++ });
    document.dispatchEvent(new Event("turbo:before-cache"));
    cache.release();
    const pendingAfterRelease = cache.pending;
    for (let tick = 0; tick <= SNAPSHOT_TICKS; tick++) await nextTick(); // past the window: no restore at all means it was dropped
    document.dispatchEvent(new Event("turbo:before-cache"));
    for (let tick = 0; tick <= SNAPSHOT_TICKS; tick++) await nextTick(); // past the window: no restore at all means it was dropped
    cache.release(); // idempotent
    return { teardowns, restores, pendingAfterRelease, pendingAfterSecondRelease: cache.pending };
  });
  assert.deepEqual(released, { teardowns: 1, restores: 0, pendingAfterRelease: false, pendingAfterSecondRelease: false });
});

primitiveTest("turbo_cache: a second before-cache inside the window hands the pending state to teardown and restarts the window", async (page) => {
  const timeline = await page.evaluate(async () => {
    const { turboCacheRestore, SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache");
    const nextTick = () => new Promise((resolve) => setTimeout(resolve, 0));
    const log = [];
    let open = true;
    const cache = turboCacheRestore({
      teardown: ({ pending, state }) => {
        log.push(["teardown", { pending, state }]);
        const wasOpen = open || (pending && state);
        open = false;
        return wasOpen;
      },
      restore: (wasOpen) => log.push(["restore", wasOpen]),
    });
    document.dispatchEvent(new Event("turbo:before-cache"));
    await nextTick();
    document.dispatchEvent(new Event("turbo:before-cache")); // one tick in: the first restore has not run yet
    const afterSecond = { pending: cache.pending, log: [...log] };
    // Counted from the second event: a primitive that kept the first window would restore on the first tick here, the tick Turbo
    // takes the second snapshot in.
    const perTick = [];
    for (let tick = 1; tick <= SNAPSHOT_TICKS; tick++) {
      await nextTick();
      perTick.push({ pending: cache.pending, restores: log.filter(([kind]) => kind === "restore").length });
    }
    for (let tick = 0; tick < SNAPSHOT_TICKS; tick++) await nextTick(); // no restore after the counted one
    cache.release();
    return { afterSecond, perTick, log };
  });
  assert.deepEqual(timeline.afterSecond.log, [["teardown", { pending: false, state: undefined }], ["teardown", { pending: true, state: true }]]);
  assert.equal(timeline.afterSecond.pending, true);
  assert.deepEqual(timeline.perTick, [{ pending: true, restores: 0 }, { pending: false, restores: 1 }]);
  assert.deepEqual(timeline.log.slice(2), [["restore", true]]);
});

primitiveTest("turbo_cache: two owners on one page keep separate listeners, states and timers", async (page) => {
  const restoredStates = await page.evaluate(async () => {
    const { turboCacheRestore, SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache");
    const nextTick = () => new Promise((resolve) => setTimeout(resolve, 0));
    const log = [];
    const first = turboCacheRestore({ teardown: () => "first", restore: (state) => log.push(state) });
    const second = turboCacheRestore({ teardown: () => "second", restore: (state) => log.push(state) });
    document.dispatchEvent(new Event("turbo:before-cache"));
    second.release();
    for (let tick = 0; tick <= SNAPSHOT_TICKS; tick++) await nextTick(); // past the window: no restore at all means it was dropped
    first.release();
    return log;
  });
  assert.deepEqual(restoredStates, ["first"]);
});
