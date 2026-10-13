// positioner: floating-ui placement with Radix's REAL middleware stack (@radix-ui/react-popper 1.3.x, PopperContent).
// Spec: .ai/skills/radix-stimulus/references/primitives.md. Parity: docs/shadcn-port/scenarios/_primitives-positioner.json.
//
// Known divergences: none.
//
// Contract (same DOM as Radix):
//   wrapper = content.parentElement  `div[data-radix-popper-content-wrapper]`, created around `content` when missing.
//             It is the FLOATING element: it gets position/transform/min-width/z-index and the CSS variables
//             --radix-popper-{transform-origin,available-width,available-height,anchor-width,anchor-height}.
//   content gets data-side / data-align (the PLACED side/align after flip), and `animation: none` until placed.
//   anchor  gets data-radix-popper-side / data-radix-popper-align while mounted.
//   arrow   (optional) is the span PopperArrow renders around the arrow graphic; positioned like PopperArrow.
import { arrow as arrowMiddleware, autoUpdate, computePosition, flip, hide, limitShift, offset, shift, size } from "@floating-ui/dom"

const OPPOSITE_SIDE = { top: "bottom", right: "left", bottom: "top", left: "right" }
const ARROW_TRANSFORM_ORIGIN = { top: "", right: "0 0", bottom: "center 0", left: "100% 0" }
const ARROW_TRANSFORM = {
  top: "translateY(100%)",
  right: "translateY(50%) rotate(90deg) translateX(-50%)",
  bottom: "rotate(180deg)",
  left: "translateY(50%) rotate(-90deg) translateX(50%)"
}
const DEFAULTS = {
  side: "bottom",
  sideOffset: 0,
  align: "center",
  alignOffset: 0,
  arrowPadding: 0,
  avoidCollisions: true,
  collisionBoundary: [],
  collisionPadding: 0,
  sticky: "partial",
  hideWhenDetached: false,
  updatePositionStrategy: "optimized"
}

export function sideAndAlign(placement) {
  const [side, align = "center"] = placement.split("-")
  return [side, align]
}

// Wraps `content` in the Radix wrapper unless it already sits in one.
export function ensureWrapper(content) {
  const parent = content.parentElement
  if (parent?.hasAttribute("data-radix-popper-content-wrapper")) return parent
  const wrapper = content.ownerDocument.createElement("div")
  wrapper.setAttribute("data-radix-popper-content-wrapper", "")
  content.before(wrapper)
  wrapper.append(content)
  return wrapper
}

// Radix's own middleware (react-popper transformOrigin): origin of the open animation, honoring the arrow.
const transformOrigin = (options) => ({
  name: "transformOrigin",
  options,
  fn({ placement, rects, middlewareData }) {
    const isArrowHidden = middlewareData.arrow?.centerOffset !== 0
    const arrowWidth = isArrowHidden ? 0 : options.arrowWidth
    const arrowHeight = isArrowHidden ? 0 : options.arrowHeight
    const [placedSide, placedAlign] = sideAndAlign(placement)
    const noArrowAlign = { start: "0%", center: "50%", end: "100%" }[placedAlign]
    const arrowXCenter = (middlewareData.arrow?.x ?? 0) + arrowWidth / 2
    const arrowYCenter = (middlewareData.arrow?.y ?? 0) + arrowHeight / 2
    let x = ""
    let y = ""
    if (placedSide === "bottom") {
      x = isArrowHidden ? noArrowAlign : `${arrowXCenter}px`
      y = `${-arrowHeight}px`
    } else if (placedSide === "top") {
      x = isArrowHidden ? noArrowAlign : `${arrowXCenter}px`
      y = `${rects.floating.height + arrowHeight}px`
    } else if (placedSide === "right") {
      x = `${-arrowHeight}px`
      y = isArrowHidden ? noArrowAlign : `${arrowYCenter}px`
    } else if (placedSide === "left") {
      x = `${rects.floating.width + arrowHeight}px`
      y = isArrowHidden ? noArrowAlign : `${arrowYCenter}px`
    }
    return { data: { x, y } }
  }
})

// Callers pass through optional values (Stimulus values, JSON): undefined means "use the Radix default".
const defined = (object) => Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined))

const roundByDPR = (element, value) => {
  const dpr = (element.ownerDocument.defaultView || window).devicePixelRatio || 1
  return Math.round(value * dpr) / dpr
}

// positioner(anchor, content, options) -> { update(partialOptions), release() }
// options: side sideOffset align alignOffset arrow(span element) arrowPadding avoidCollisions collisionBoundary(Element|Element[])
//          collisionPadding(number|{top,right,bottom,left}) sticky("partial"|"always") hideWhenDetached
//          updatePositionStrategy("optimized"|"always") dir onPlaced
export function positioner(anchor, content, initial = {}) {
  let options = { ...DEFAULTS, ...defined(initial) }
  const wrapper = ensureWrapper(content)
  let released = false
  let positioned = false
  let token = 0
  let stopAutoUpdate = null
  let arrowSize = { width: 0, height: 0 }
  let arrowObserver = null
  let observedArrow = null

  const measureArrow = () => {
    const { arrow } = options
    arrowSize = arrow ? { width: arrow.offsetWidth, height: arrow.offsetHeight } : { width: 0, height: 0 }
  }

  const observeArrow = () => {
    if (observedArrow === options.arrow) return
    arrowObserver?.disconnect()
    observedArrow = options.arrow
    measureArrow()
    if (!observedArrow) return
    arrowObserver = new ResizeObserver(() => {
      const before = arrowSize
      measureArrow()
      if (before.width !== arrowSize.width || before.height !== arrowSize.height) update()
    })
    arrowObserver.observe(observedArrow, { box: "border-box" })
  }

  const detectOverflowOptions = () => {
    const { collisionPadding, collisionBoundary } = options
    const boundary = (Array.isArray(collisionBoundary) ? collisionBoundary : [collisionBoundary]).filter((b) => b !== null && b !== undefined)
    return {
      padding: typeof collisionPadding === "number" ? collisionPadding : { top: 0, right: 0, bottom: 0, left: 0, ...collisionPadding },
      boundary,
      // with `strategy: "fixed"`, this is the only way to get it to respect boundaries
      altBoundary: boundary.length > 0
    }
  }

  const middleware = () => {
    const detect = detectOverflowOptions()
    const { avoidCollisions, sticky, arrow, arrowPadding, hideWhenDetached } = options
    return [
      offset({ mainAxis: options.sideOffset + arrowSize.height, alignmentAxis: options.alignOffset }),
      avoidCollisions && shift({ mainAxis: true, crossAxis: false, limiter: sticky === "partial" ? limitShift() : undefined, ...detect }),
      avoidCollisions && flip({ ...detect }),
      size({
        ...detect,
        apply({ elements, rects, availableWidth, availableHeight }) {
          const style = elements.floating.style
          style.setProperty("--radix-popper-available-width", `${availableWidth}px`)
          style.setProperty("--radix-popper-available-height", `${availableHeight}px`)
          style.setProperty("--radix-popper-anchor-width", `${rects.reference.width}px`)
          style.setProperty("--radix-popper-anchor-height", `${rects.reference.height}px`)
        }
      }),
      arrow && arrowMiddleware({ element: arrow, padding: arrowPadding }),
      transformOrigin({ arrowWidth: arrowSize.width, arrowHeight: arrowSize.height }),
      hideWhenDetached && hide({ strategy: "referenceHidden", ...detect, boundary: detect.boundary.length > 0 ? detect.boundary : undefined })
    ]
  }

  const placementOf = () => options.side + (options.align !== "center" ? `-${options.align}` : "")

  const apply = ({ x, y, placement, middlewareData }) => {
    const [side, align] = sideAndAlign(placement)
    const style = wrapper.style
    style.position = "fixed"
    style.left = "0px"
    style.top = "0px"
    style.transform = `translate(${roundByDPR(wrapper, x)}px, ${roundByDPR(wrapper, y)}px)`
    if (((wrapper.ownerDocument.defaultView || window).devicePixelRatio || 1) >= 1.5) style.willChange = "transform"
    style.minWidth = "max-content"
    style.setProperty("--radix-popper-transform-origin", [middlewareData.transformOrigin?.x, middlewareData.transformOrigin?.y].join(" "))
    if (middlewareData.hide?.referenceHidden) {
      style.visibility = "hidden"
      style.pointerEvents = "none"
    } else {
      style.removeProperty("visibility")
      style.removeProperty("pointer-events")
    }
    content.setAttribute("data-side", side)
    content.setAttribute("data-align", align)
    anchor.setAttribute("data-radix-popper-side", side)
    anchor.setAttribute("data-radix-popper-align", align)
    content.style.removeProperty("animation")
    applyArrow(side, middlewareData.arrow)
    if (!positioned) {
      positioned = true
      options.onPlaced?.()
    }
  }

  // PopperArrow: the span sits on the edge facing the anchor and slides along it.
  const applyArrow = (side, data) => {
    const { arrow } = options
    if (!arrow) return
    const style = arrow.style
    style.position = "absolute"
    for (const edge of ["top", "right", "bottom", "left"]) style.removeProperty(edge)
    if (data?.x != null) style.left = `${data.x}px`
    if (data?.y != null) style.top = `${data.y}px`
    style[OPPOSITE_SIDE[side]] = "0px"
    style.transformOrigin = ARROW_TRANSFORM_ORIGIN[side]
    style.transform = ARROW_TRANSFORM[side]
    style.visibility = data?.centerOffset !== 0 ? "hidden" : ""
  }

  const update = async (next) => {
    if (next) {
      options = { ...options, ...defined(next) }
      observeArrow()
    }
    if (released) return
    const current = ++token
    const result = await computePosition(anchor, wrapper, { placement: placementOf(), strategy: "fixed", middleware: middleware().filter(Boolean) })
    if (released || current !== token) return
    apply(result)
  }

  const observe = () => {
    stopAutoUpdate?.()
    stopAutoUpdate = autoUpdate(anchor, wrapper, () => update(), { animationFrame: options.updatePositionStrategy === "always" })
  }

  // Off the page while measuring, no animation until placed (react-popper).
  wrapper.style.position = "fixed"
  wrapper.style.left = "0px"
  wrapper.style.top = "0px"
  wrapper.style.transform = "translate(0, -200%)"
  wrapper.style.minWidth = "max-content"
  wrapper.style.zIndex = getComputedStyle(content).zIndex
  if (options.dir) wrapper.setAttribute("dir", options.dir)
  content.style.animation = "none"
  observeArrow()
  observe()

  return {
    update: (next) => {
      const strategyChanged = next && "updatePositionStrategy" in next && next.updatePositionStrategy !== options.updatePositionStrategy
      update(next)
      if (strategyChanged) observe()
    },
    release() {
      released = true
      stopAutoUpdate?.()
      arrowObserver?.disconnect()
      anchor.removeAttribute("data-radix-popper-side")
      anchor.removeAttribute("data-radix-popper-align")
    }
  }
}
