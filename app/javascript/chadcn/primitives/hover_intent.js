// hover_intent: open/close delay timers with the skip-delay provider state of Radix Tooltip, HoverCard and NavigationMenu.
// Sources: @radix-ui/react-tooltip (TooltipProvider/Tooltip: skip-delay, delayed vs instant open), @radix-ui/react-hover-card
// (openDelay/closeDelay timers). Spec: .ai/skills/radix-stimulus/references/primitives.md.
// Parity: docs/shadcn-port/scenarios/_primitives-hover-intent.json.
//
// Known divergences: none.
// `hoverIntent.release()` does not release its provider: the owner releases both.
//
//   const provider = hoverProvider({ skipDelayDuration: 300 })          // shared by every tooltip under one Provider
//   const intent = hoverIntent({ provider, openDelay: 700, closeDelay: 0, onOpen({ delayed }) {}, onClose() {} })
//   trigger pointermove (once per entry) -> intent.enter()       trigger pointerleave -> intent.leave()
//   focus -> intent.open()                                       blur / click / pointerdown -> intent.close()
//
// `onOpen` / `onClose` fire only on transitions. `delayed` is true when the open timer fired (Radix `delayed-open`),
// false for an immediate open (`instant-open`, skip window or focus).

// Provider state: `isOpenDelayed` starts true; any open clears the skip timer and turns the delay off; any close restarts the
// skip window, after which the delay applies again. With skipDelayDuration <= 0 the state never changes (Radix).
/**
 * Shared skip-delay state of a Tooltip provider.
 * @param {object} [options]
 * @param {number} [options.skipDelayDuration=300] Window (ms) after a close in which the next open skips its delay; <= 0 disables it.
 * @returns {{ readonly isOpenDelayed: boolean, isPointerInTransit: boolean, onOpen: () => void, onClose: () => void, release: () => void }}
 *   `isPointerInTransit` is a read/write accessor; `isOpenDelayed` is read-only.
 * @example
 * const provider = hoverProvider({ skipDelayDuration: 300 })
 */
export function hoverProvider({ skipDelayDuration = 300 } = {}) {
  let isOpenDelayed = true
  let isPointerInTransit = false
  let timer = 0

  return {
    get isOpenDelayed() {
      return isOpenDelayed
    },
    // True while a pointer crosses a grace area between trigger and content (Radix isPointerInTransit): triggers must not re-enter.
    get isPointerInTransit() {
      return isPointerInTransit
    },
    set isPointerInTransit(value) {
      isPointerInTransit = value
    },
    onOpen() {
      if (skipDelayDuration <= 0) return
      window.clearTimeout(timer)
      isOpenDelayed = false
    },
    onClose() {
      if (skipDelayDuration <= 0) return
      window.clearTimeout(timer)
      timer = window.setTimeout(() => (isOpenDelayed = true), skipDelayDuration)
    },
    release() {
      window.clearTimeout(timer)
    }
  }
}

/**
 * Open/close delay timers for hover-driven surfaces (tooltip, hover card, navigation menu).
 * @param {object} [options]
 * @param {ReturnType<typeof hoverProvider> | null} [options.provider=null]
 * @param {number} [options.openDelay=700]
 * @param {number} [options.closeDelay=0]
 * @param {(info: { delayed: boolean }) => void} [options.onOpen] Fires on the closed -> open transition only.
 * @param {() => void} [options.onClose] Fires on the open -> closed transition only.
 * @param {boolean} [options.open=false] Initial state.
 * @returns {{ readonly isOpen: boolean, enter: () => void, leave: () => void, cancelOpen: () => void, open: () => void, close: () => void, sync: (value: boolean) => void, release: () => void }}
 *   `sync(value)` is controlled mode: the owner changed the state itself; it sets `isOpen` without firing callbacks.
 * @example
 * const intent = hoverIntent({ provider, openDelay: 700, onOpen: ({ delayed }) => show(delayed) })
 * intent.enter()
 */
export function hoverIntent({ provider = null, openDelay = 700, closeDelay = 0, onOpen, onClose, open = false } = {}) {
  let isOpen = open
  let openTimer = 0
  let closeTimer = 0

  const clearOpenTimer = () => {
    window.clearTimeout(openTimer)
    openTimer = 0
  }
  const clearCloseTimer = () => {
    window.clearTimeout(closeTimer)
    closeTimer = 0
  }

  const openNow = (delayed) => {
    clearOpenTimer()
    clearCloseTimer()
    if (isOpen) return
    isOpen = true
    provider?.onOpen()
    onOpen?.({ delayed })
  }

  const closeNow = () => {
    clearOpenTimer()
    clearCloseTimer()
    if (!isOpen) return
    isOpen = false
    provider?.onClose()
    onClose?.()
  }

  return {
    get isOpen() {
      return isOpen
    },
    // Pointer entered: open after `openDelay` (Tooltip: only while the provider's delay is on, else immediately).
    enter() {
      clearCloseTimer()
      if (provider && !provider.isOpenDelayed) return openNow(false)
      clearOpenTimer()
      openTimer = window.setTimeout(() => {
        openTimer = 0
        openNow(true)
      }, openDelay)
    },
    // Pointer left: cancel a pending open, then close after `closeDelay` (immediately when 0).
    leave() {
      clearOpenTimer()
      if (closeDelay > 0) {
        clearCloseTimer()
        closeTimer = window.setTimeout(() => {
          closeTimer = 0
          closeNow()
        }, closeDelay)
      } else {
        closeNow()
      }
    },
    // Pointer left a hoverable trigger whose content may be reached: only the pending open is dropped (Tooltip, hoverable content).
    cancelOpen: clearOpenTimer,
    open: () => openNow(false),
    close: closeNow,
    // Controlled mode: the owner changed the state itself; keep the timers consistent.
    sync(value) {
      isOpen = value
      clearOpenTimer()
      clearCloseTimer()
    },
    release() {
      clearOpenTimer()
      clearCloseTimer()
    }
  }
}
