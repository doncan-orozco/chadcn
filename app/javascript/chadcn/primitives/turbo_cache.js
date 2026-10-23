// Turbo page cache restore for a controller that rewrites its DOM at connect time (mounted templates, portaled parts, measured
// styles). Turbo snapshots the live DOM one timer tick after `turbo:before-cache` (PageView#cacheSnapshot -> nextEventLoopTick),
// and it does so for every visit, also the ones that keep the page (a link to #hash). So the owner tears its runtime DOM down
// synchronously on the event (the snapshot holds the server markup) and is set up again `SNAPSHOT_TICKS` ticks later, if it is
// still connected: a real navigation replaces the page and disconnects it first, and `release()` from `disconnect()` drops the
// pending restore.
//
// Not a Radix port: Radix has no page cache. Known divergences: none (the reference is Turbo's snapshot timing).

/** Timer ticks between `turbo:before-cache` and the restore: Turbo's snapshot tick, then one more. */
export const SNAPSHOT_TICKS = 2

/**
 * Registers the Turbo page cache scaffold for one owner (a Stimulus controller) on `document`.
 *
 * @param {object} options
 * @param {(cancelled: { pending: boolean, state: unknown }) => unknown} options.teardown Runs synchronously on
 *   `turbo:before-cache`. Receives the restore it replaces (`pending` is true when a second event arrives inside the window,
 *   `state` is what the first teardown returned) so the owner can carry it forward. Its return value is the state of the restore.
 *   If it throws, no restore is scheduled (the owner is in an unknown state); the browser reports the error as an uncaught
 *   listener error, it is not rethrown to Turbo's dispatch.
 * @param {(state: unknown) => void} options.restore Runs `SNAPSHOT_TICKS` timer ticks after the last event with teardown's
 *   state, unless `release()` ran first or a second event restarted the window.
 * @returns {{ readonly pending: boolean, release: () => void }}
 *   - `pending`: true between the event and the restore. Owners refuse user interaction meanwhile (the DOM is in its snapshot shape).
 *   - `release()`: idempotent; removes the listener and clears a pending restore. Call it from `disconnect()`.
 * @example
 * connect() {
 *   this.#setup()
 *   this.cache = turboCacheRestore({ teardown: () => this.#teardown(), restore: () => this.#setup() })
 * }
 * disconnect() {
 *   this.cache?.release()
 *   this.#teardown()
 * }
 */
export function turboCacheRestore({ teardown, restore }) {
  let timer = null
  let state

  const cancel = () => {
    clearTimeout(timer)
    timer = null
    state = undefined
  }

  const countdown = (ticks) => {
    timer = setTimeout(() => {
      if (ticks > 1) return countdown(ticks - 1)
      const restored = state
      cancel()
      restore(restored)
    })
  }

  const onBeforeCache = () => {
    const cancelled = { pending: timer !== null, state }
    cancel()
    state = teardown(cancelled)
    countdown(SNAPSHOT_TICKS)
  }

  document.addEventListener("turbo:before-cache", onBeforeCache)

  return {
    get pending() {
      return timer !== null
    },
    release() {
      cancel()
      document.removeEventListener("turbo:before-cache", onBeforeCache)
    },
  }
}
