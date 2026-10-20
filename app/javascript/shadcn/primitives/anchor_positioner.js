// anchor_positioner: floating-ui placement with Base UI's middleware stack (@base-ui/react `useAnchorPositioning`, 1.9.0), used by
// Combobox. `positioner.js` stays the Radix flavour; this is its Base UI sibling and shares nothing but `sideAndAlign` with it.
// Spec: dev/port/specs/combobox.md (Positioning). Parity: the combobox placement scenarios.
//
// Known divergences: the arrow is never rendered (Base UI's fake arrow element is created the same way), `adaptiveOrigin`,
// `sticky`, `positionMethod: "fixed"` and `disableAnchorTracking` are not offered.
//
// Contract (same DOM as Base UI):
//   floating  IS the element that gets the position: no wrapper is created. It receives `position`, `top`, `left`, `transform`,
//             `opacity: 0` until the first placement, and the CSS variables --available-width, --available-height,
//             --anchor-width, --anchor-height and --transform-origin.
//   floating  gets `data-side` (logical: "inline-start"/"inline-end" when asked for), `data-align` and, while the anchor is clipped,
//             `data-anchor-hidden`.
//   collisions flip top/bottom only (`fallbackAxisSide: "none"`), `collisionPadding` 5 (flip: +1 and +1 more towards the preferred
//             side), shift on the main axis; `lazyFlip` keeps the side the popup first flipped to while it resizes.
import { arrow, autoUpdate, computePosition, detectOverflow, flip, limitShift, offset, shift, size } from "@floating-ui/dom"
import { sideAndAlign } from "shadcn/primitives/positioner"

const DEFAULTS = {
  side: "bottom",
  sideOffset: 0,
  align: "center",
  alignOffset: 0,
  collisionPadding: 5,
  collisionBoundary: "clippingAncestors",
  lazyFlip: false,
  dir: "ltr"
}
const BIAS = 1

// Callers pass through optional values (Stimulus values, JSON): undefined means "use the default".
const defined = (object) => Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined && value !== null))

const roundByDPR = (element, value) => {
  const dpr = (element.ownerDocument.defaultView || window).devicePixelRatio || 1
  return Math.round(value * dpr) / dpr
}

const physicalSide = (side, rtl) => ({ top: "top", right: "right", bottom: "bottom", left: "left", "inline-end": rtl ? "left" : "right", "inline-start": rtl ? "right" : "left" })[side]

// Rendered physical side back to the name the caller asked with (data-side keeps "inline-start"/"inline-end").
const logicalSide = (requested, rendered, rtl) => {
  if (requested !== "inline-start" && requested !== "inline-end") return rendered
  return { top: "top", bottom: "bottom", right: rtl ? "inline-start" : "inline-end", left: rtl ? "inline-end" : "inline-start" }[rendered]
}

// Base UI `hide` middleware: the anchor is clipped (or has no box at all).
const hide = {
  name: "hide",
  async fn(state) {
    const { width, height, x, y } = state.rects.reference
    const anchorHidden = width === 0 && height === 0 && x === 0 && y === 0
    const overflow = await detectOverflow(state, { elementContext: "reference" })
    const referenceHidden = overflow.top - height >= 0 || overflow.right - width >= 0 || overflow.bottom - height >= 0 || overflow.left - width >= 0
    return { data: { referenceHidden: referenceHidden || anchorHidden } }
  }
}

/**
 * Positions `floating` against `anchor` with Base UI's middleware stack (offset, shift/flip, size, arrow, transformOrigin, hide).
 * Do not call update() after release().
 * @param {Element} anchor
 * @param {HTMLElement} floating The positioner element itself (no wrapper is added).
 * @param {object} [initial]
 * @param {"top" | "right" | "bottom" | "left" | "inline-start" | "inline-end"} [initial.side="bottom"]
 * @param {number} [initial.sideOffset=0]
 * @param {"start" | "center" | "end"} [initial.align="center"]
 * @param {number} [initial.alignOffset=0]
 * @param {number} [initial.collisionPadding=5]
 * @param {"clippingAncestors" | Element | Element[]} [initial.collisionBoundary="clippingAncestors"]
 * @param {boolean} [initial.lazyFlip=false] Keep the side the popup first flipped to while it resizes.
 * @param {"ltr" | "rtl"} [initial.dir="ltr"] Resolves `inline-start` / `inline-end`.
 * @param {(placed: { side: string, align: string, anchorHidden: boolean }) => void} [initial.onPlace] Runs after every placement.
 * @returns {{ update: (options?: object) => void, release: () => void }} `release()` stops autoUpdate; the styles and
 *   `data-side` / `data-align` stay as last placed. It is idempotent.
 * @example
 * const placement = anchorPositioner(inputEl, positionerEl, { side: "bottom", sideOffset: 6, align: "start", lazyFlip: true })
 * placement.release()
 */
export function anchorPositioner(anchor, floating, initial = {}) {
  let options = { ...DEFAULTS, ...defined(initial) }
  let released = false
  let positioned = false
  let token = 0
  let stopAutoUpdate = null
  let lockedSide = null
  const fakeArrow = floating.ownerDocument.createElement("div")

  const rtl = () => options.dir === "rtl"
  const requestedSide = () => lockedSide ?? physicalSide(options.side, rtl())
  const placementOf = () => {
    const side = requestedSide()
    return options.align === "center" ? side : `${side}-${options.align}`
  }

  const middleware = () => {
    const { collisionPadding: padding, collisionBoundary: boundary, align, alignOffset, sideOffset } = options
    const common = { boundary, padding }
    const preferred = options.side
    const flipPadding = {
      top: padding + BIAS + (preferred === "bottom" ? BIAS : 0),
      right: padding + BIAS + (preferred === "left" ? BIAS : 0),
      bottom: padding + BIAS + (preferred === "top" ? BIAS : 0),
      left: padding + BIAS + (preferred === "right" ? BIAS : 0)
    }
    const flipMiddleware = flip({ boundary, padding: flipPadding, mainAxis: true, crossAxis: "alignment", fallbackAxisSideDirection: "none" })
    const shiftMiddleware = shift({ ...common, mainAxis: true, crossAxis: false, limiter: limitShift() })
    return [
      offset({ mainAxis: sideOffset, crossAxis: alignOffset, alignmentAxis: alignOffset }),
      // https://floating-ui.com/docs/flip#combining-with-shift
      ...(align === "center" ? [shiftMiddleware, flipMiddleware] : [flipMiddleware, shiftMiddleware]),
      size({
        ...common,
        apply({ elements, availableWidth, availableHeight, rects }) {
          const style = elements.floating.style
          style.setProperty("--available-width", `${availableWidth}px`)
          style.setProperty("--available-height", `${availableHeight}px`)
          // Snap the anchor box to device pixels so the popup's width matches the anchor's.
          const dpr = (elements.floating.ownerDocument.defaultView || window).devicePixelRatio || 1
          const { x, y, width, height } = rects.reference
          style.setProperty("--anchor-width", `${(Math.round((x + width) * dpr) - Math.round(x * dpr)) / dpr}px`)
          style.setProperty("--anchor-height", `${(Math.round((y + height) * dpr) - Math.round(y * dpr)) / dpr}px`)
        }
      }),
      arrow({ element: fakeArrow, padding: 0 }),
      transformOrigin,
      hide
    ]
  }

  // Base UI's own middleware: the open animation grows from the aligned edge, or from the (fake) arrow's centre.
  const transformOrigin = {
    name: "transformOrigin",
    fn({ elements, middlewareData, placement, platform }) {
      const [side, align] = sideAndAlign(placement)
      const vertical = side === "top" || side === "bottom"
      const aligned = placement.includes("-")
      let cross
      if (aligned && Math.abs((vertical ? middlewareData.shift?.x : middlewareData.shift?.y) || 0) <= 1) {
        cross = (align === "start") === (vertical && platform.isRTL?.(elements.floating) === true) ? "100%" : "0%"
      } else {
        cross = `${(vertical ? middlewareData.arrow?.x : middlewareData.arrow?.y) || 0}px`
      }
      const main = side === "top" || side === "left" ? `calc(100% + ${options.sideOffset}px)` : `${-options.sideOffset}px`
      elements.floating.style.setProperty("--transform-origin", vertical ? `${cross} ${main}` : `${main} ${cross}`)
      return {}
    }
  }

  const apply = ({ x, y, placement, middlewareData }) => {
    const [side, align] = sideAndAlign(placement)
    const style = floating.style
    if (!positioned) {
      positioned = true
      style.position = "absolute"
      style.removeProperty("opacity")
    }
    style.top = "0px"
    style.left = "0px"
    style.transform = `translate(${roundByDPR(floating, x)}px, ${roundByDPR(floating, y)}px)`
    if (((floating.ownerDocument.defaultView || window).devicePixelRatio || 1) >= 1.5) style.willChange = "transform"
    const anchorHidden = Boolean(middlewareData.hide?.referenceHidden)
    const logical = logicalSide(options.side, side, rtl())
    floating.setAttribute("data-side", logical)
    floating.setAttribute("data-align", align)
    floating.toggleAttribute("data-anchor-hidden", anchorHidden)
    options.onPlace?.({ side: logical, align, anchorHidden })
    // lazyFlip: the first flip sticks while the list resizes during the same open.
    if (options.lazyFlip && lockedSide === null && side !== requestedSide()) {
      lockedSide = side
      update()
    }
  }

  const update = async (next) => {
    if (next) options = { ...options, ...defined(next) }
    if (released) return
    const current = ++token
    const result = await computePosition(anchor, floating, { placement: placementOf(), strategy: "absolute", middleware: middleware() })
    if (released || current !== token) return
    apply(result)
  }

  // Off the page and invisible while measuring (Base UI renders it fixed with opacity 0 until the first placement).
  floating.style.position = "fixed"
  floating.style.top = "0px"
  floating.style.left = "0px"
  floating.style.opacity = "0"
  floating.style.setProperty("--available-width", "100vw")
  floating.style.setProperty("--available-height", "100vh")
  stopAutoUpdate = autoUpdate(anchor, floating, () => update(), { ancestorScroll: true, elementResize: true, layoutShift: true })

  return {
    update: (next) => { update(next) },
    release() {
      released = true
      stopAutoUpdate?.()
      stopAutoUpdate = null
    }
  }
}
