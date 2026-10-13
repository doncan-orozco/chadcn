// Port of @radix-ui/react-presence. Known divergences: none.
//
// Radix keeps an element mounted after `present` turns false until its exit animation ends. The caller sets
// `data-state="closed"` first, then calls `exit()`; this module decides, from the computed `animation-name`, whether
// to unmount right away (no animation, `display: none`, or the same animation as the open state) or to wait for
// `animationend` / `animationcancel` on the element itself.
//
//   const p = presence(el, { onExited: () => mount.unmount() })
//   el.dataset.state = "closed"; p.exit()      // starts the exit
//   p.enter()                                   // re-opened: cancels a pending exit
//   p.release()                                 // disconnect cleanup
export function presence(el, { onExited } = {}) {
  let animationName = getComputedStyle(el).animationName
  let exiting = false

  const onStart = (event) => {
    if (event.target === el) animationName = getComputedStyle(el).animationName
  }
  const onEnd = (event) => {
    if (event.target !== el || !exiting) return
    // Radix isCurrentAnimation: the cancelled enter animation must not end the exit.
    if (event.animationName && !getComputedStyle(el).animationName.includes(event.animationName)) return
    finish()
  }

  const finish = () => {
    stop()
    onExited?.()
  }
  const stop = () => {
    exiting = false
    el.removeEventListener("animationend", onEnd)
    el.removeEventListener("animationcancel", onEnd)
  }

  el.addEventListener("animationstart", onStart)

  return {
    // Call after the element reached its open state so the "previous" animation name is the open one.
    enter() {
      stop()
      animationName = getComputedStyle(el).animationName
    },
    exit() {
      stop()
      const styles = getComputedStyle(el)
      const current = styles.animationName
      const previous = animationName
      animationName = current
      if (styles.display === "none" || current === "none" || previous === current) return finish()
      exiting = true
      el.addEventListener("animationend", onEnd)
      el.addEventListener("animationcancel", onEnd)
    },
    release() {
      stop()
      el.removeEventListener("animationstart", onStart)
    },
  }
}
