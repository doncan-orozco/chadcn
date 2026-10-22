// Open/closed mechanics of @radix-ui/react-collapsible's content, shared by Collapsible and Accordion.
// Known divergences: none (the caller mounts/unmounts the children, see template_mount.js, from `onExited` and `open`).
//
//   const content = collapsibleContent(el, { open: true, onExited: () => mount.unmount() })
//   content.setOpen(false)    // data-state=closed, waits for the exit animation (presence.js), then hidden + onExited
//   content.setOpen(true)     // hidden removed, data-state=open, size variables measured
//   content.release()
//
// Writes data-state, `hidden`, `--radix-collapsible-content-height` and `--radix-collapsible-content-width` (measured with
// transitions and animations suspended so a height animation can start from the real size). A content that is open on
// first paint keeps them suspended until its first close or reopen measurement after the next animation frame (Radix clears
// isMountAnimationPreventedRef in a requestAnimationFrame), so it does not animate in on load. Server markup may already carry
// that suspension inline (`transition-duration: 0s; animation-name: none`); it is not the content's own style, so it is not
// restored as one.
import { presence } from "chadcn/primitives/presence"

/**
 * Open/closed mechanics of a collapsible content element (data-state, `hidden`, size CSS variables, exit animation).
 * @param {HTMLElement} el The content element.
 * @param {object} [options]
 * @param {boolean} [options.open=false] Whether the content is open on first paint (its animations stay suspended until the next frame).
 * @param {() => void} [options.onExited] Runs once the content was hidden: after the exit animation ended, or immediately when there is none.
 * @returns {{ setOpen: (open: boolean) => void, release: () => void }} `setOpen` writes the state; `release` cancels the pending frame and exit listeners.
 * @example
 * const content = collapsibleContent(el, { open: true, onExited: () => mount.unmount() })
 * content.setOpen(false)
 * content.release()
 */
export function collapsibleContent(el, { open = false, onExited } = {}) {
  const exit = presence(el, { onExited: () => hide() })
  let originalStyles = open ? { transitionDuration: "", animationName: "" } : null
  let preventMountAnimation = open
  const frame = open ? requestAnimationFrame(() => (preventMountAnimation = false)) : null

  const measure = () => {
    originalStyles ??= { transitionDuration: el.style.transitionDuration, animationName: el.style.animationName }
    el.style.transitionDuration = "0s"
    el.style.animationName = "none"
    const rect = el.getBoundingClientRect()
    if (!preventMountAnimation) {
      el.style.transitionDuration = originalStyles.transitionDuration
      el.style.animationName = originalStyles.animationName
    }
    return rect
  }

  const apply = (rect) => {
    setSize("height", rect.height)
    setSize("width", rect.width)
  }

  const setSize = (name, value) => {
    const property = `--radix-collapsible-content-${name}`
    if (value) el.style.setProperty(property, `${value}px`)
    else el.style.removeProperty(property)
  }

  const hide = () => {
    el.hidden = true
    apply(measure())
    onExited?.()
  }

  if (open) apply(measure())

  return {
    setOpen(next) {
      if (next) {
        el.dataset.state = "open"
        el.hidden = false
        exit.enter()
        // Radix measures twice on open: once when `open` flips and again when Presence reports the node present, after
        // the first size variables were applied (content that depends on them changes size in between).
        apply(measure())
        apply(measure())
        return
      }
      // Same order as Radix: state, measurement (animations suspended), Presence reads the computed animation (which
      // restarts the exit animation), and only then the size variables are written (Radix sets them in the re-render).
      el.dataset.state = "closed"
      const rect = measure()
      exit.exit()
      if (!el.hidden) apply(rect)
    },
    release() {
      cancelAnimationFrame(frame)
      exit.release()
    },
  }
}
