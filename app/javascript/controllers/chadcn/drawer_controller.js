import DialogController from "controllers/chadcn/dialog_controller"

// vaul 1.1.2 Drawer over Radix Dialog. Spec: dev/port/specs/drawer.md (Behavior), vaul line numbers cited as vaul:<line> are those
// of dev/react-shadcn-catalog/node_modules/vaul/dist/index.mjs.
//
// Radix Dialog is always modal inside vaul, so this controller IS the dialog controller (mounting, presence, focus scope, dismissable
// layer, scroll lock, hideOthers) with its own `modal` value fixed to true; vaul's `modal` is the `vaul-modal` value. What vaul adds
// is layered on top without touching the dialog's private state:
//   - vaul's props on the parts: the data-vaul-* attributes, repainted wherever React would re-render the Root (#paint);
//   - the callbacks vaul gives Radix (open-auto-focus prevented, focus-outside and outside presses, dismissible guard);
//   - the drag gesture, snap points, background scaling and the platform fixes (Safari position fixed, iOS prevent scroll, keyboard).
// Handle and NestedRoot are not exported by shadcn's drawer.tsx and are not ported.
const DURATION = 0.5
const EASE = "cubic-bezier(0.32,0.72,0,1)"
const TRANSITION_MS = DURATION * 1000
const VELOCITY_THRESHOLD = 0.4
const BORDER_RADIUS = 8
const WINDOW_TOP_OFFSET = 26
const DRAG_CLASS = "vaul-dragging"
const KEYBOARD_BUFFER = 24
const NON_TEXT_INPUTS = new Set(["checkbox", "radio", "range", "color", "file", "image", "button", "submit", "reset"])
const WRAPPER = "[data-vaul-drawer-wrapper], [vaul-drawer-wrapper]"

const isVertical = (direction) => direction === "top" || direction === "bottom"
const isIOS = () => /^(iPhone|iPad)/.test(navigator.platform) || (/^Mac/.test(navigator.platform) && navigator.maxTouchPoints > 1)
const isSafari = () => /^((?!chrome|android).)*safari/i.test(navigator.userAgent)
const isMobileFirefox = () => (/Firefox/.test(navigator.userAgent) && /Mobile/.test(navigator.userAgent)) || /FxiOS/.test(navigator.userAgent)
const isInput = (target) =>
  (target instanceof HTMLInputElement && !NON_TEXT_INPUTS.has(target.type)) ||
  target instanceof HTMLTextAreaElement ||
  (target instanceof HTMLElement && target.isContentEditable)
const bool = (value) => (value ? "true" : "false")
const translate3d = (direction, value) => (isVertical(direction) ? `translate3d(0, ${value}px, 0)` : `translate3d(${value}px, 0, 0)`)
const transitionOf = (property) => `${property} ${DURATION}s ${EASE}`

// vaul `set`: assigns inline styles (custom properties through setProperty).
function set(el, styles) {
  if (!(el instanceof HTMLElement)) return
  Object.entries(styles).forEach(([key, value]) => (key.startsWith("--") ? el.style.setProperty(key, value) : (el.style[key] = value)))
}

// vaul `assignStyle`: assigns and returns the function restoring the whole previous cssText.
function assignStyle(el, styles) {
  const previous = el.style.cssText
  Object.assign(el.style, styles)
  return () => (el.style.cssText = previous)
}

function getTranslate(el, direction) {
  if (!el) return null
  const transform = getComputedStyle(el).transform
  let match = transform.match(/^matrix3d\((.+)\)$/)
  if (match) return parseFloat(match[1].split(", ")[isVertical(direction) ? 13 : 12])
  match = transform.match(/^matrix\((.+)\)$/)
  return match ? parseFloat(match[1].split(", ")[isVertical(direction) ? 5 : 4]) : null
}

const dampenValue = (value) => 8 * (Math.log(value + 1) - 2)

// --- Safari / iOS fixes shared by every drawer (vaul keeps these in module scope too) ------------------------------------------------

let previousBodyPosition = null
let preventScrollCount = 0
let restorePreventScroll = null

const isScrollable = (node) => /(auto|scroll)/.test(getComputedStyle(node).overflow + getComputedStyle(node).overflowX + getComputedStyle(node).overflowY)

function getScrollParent(node) {
  if (isScrollable(node)) node = node.parentElement
  while (node && !isScrollable(node)) node = node.parentElement
  return node || document.scrollingElement || document.documentElement
}

function scrollIntoView(target) {
  const root = document.scrollingElement || document.documentElement
  while (target && target !== root) {
    const scrollable = getScrollParent(target)
    if (scrollable !== document.documentElement && scrollable !== document.body && scrollable !== target) {
      const scrollableTop = scrollable.getBoundingClientRect().top
      const targetRect = target.getBoundingClientRect()
      if (targetRect.bottom > scrollable.getBoundingClientRect().bottom + KEYBOARD_BUFFER) scrollable.scrollTop += targetRect.top - scrollableTop
    }
    target = scrollable.parentElement
  }
}

// react-aria usePreventScroll for mobile Safari (vaul:136-290).
function preventScrollMobileSafari() {
  let scrollable
  let lastY = 0
  const onTouchStart = (event) => {
    scrollable = getScrollParent(event.target)
    if (scrollable === document.documentElement && scrollable === document.body) return
    lastY = event.changedTouches[0].pageY
  }
  const onTouchMove = (event) => {
    if (!scrollable || scrollable === document.documentElement || scrollable === document.body) return event.preventDefault()
    const y = event.changedTouches[0].pageY
    const bottom = scrollable.scrollHeight - scrollable.clientHeight
    if (bottom === 0) return
    if ((scrollable.scrollTop <= 0 && y > lastY) || (scrollable.scrollTop >= bottom && y < lastY)) event.preventDefault()
    lastY = y
  }
  const onTouchEnd = (event) => {
    const target = event.target
    if (isInput(target) && target !== document.activeElement) {
      event.preventDefault()
      target.style.transform = "translateY(-2000px)"
      target.focus()
      requestAnimationFrame(() => (target.style.transform = ""))
    }
  }
  const onFocus = (event) => {
    const target = event.target
    if (!isInput(target)) return
    target.style.transform = "translateY(-2000px)"
    requestAnimationFrame(() => {
      target.style.transform = ""
      const viewport = window.visualViewport
      if (!viewport) return
      if (viewport.height < window.innerHeight) requestAnimationFrame(() => scrollIntoView(target))
      else viewport.addEventListener("resize", () => scrollIntoView(target), { once: true })
    })
  }
  const onWindowScroll = () => window.scrollTo(0, 0)

  const scrollX = window.pageXOffset
  const scrollY = window.pageYOffset
  const previousPadding = document.documentElement.style.paddingRight
  document.documentElement.style.paddingRight = `${window.innerWidth - document.documentElement.clientWidth}px`
  window.scrollTo(0, 0)
  document.addEventListener("touchstart", onTouchStart, { passive: false, capture: true })
  document.addEventListener("touchmove", onTouchMove, { passive: false, capture: true })
  document.addEventListener("touchend", onTouchEnd, { passive: false, capture: true })
  document.addEventListener("focus", onFocus, true)
  window.addEventListener("scroll", onWindowScroll)
  return () => {
    document.documentElement.style.paddingRight = previousPadding
    document.removeEventListener("touchstart", onTouchStart, { capture: true })
    document.removeEventListener("touchmove", onTouchMove, { capture: true })
    document.removeEventListener("touchend", onTouchEnd, { capture: true })
    document.removeEventListener("focus", onFocus, true)
    window.removeEventListener("scroll", onWindowScroll)
    window.scrollTo(scrollX, scrollY)
  }
}

export default class extends DialogController {
  static values = {
    vaulModal: { type: Boolean, default: true },
    direction: { type: String, default: "bottom" },
    dismissible: { type: Boolean, default: true },
    handleOnly: Boolean,
    autoFocus: Boolean,
    snapPoints: Array,
    activeSnapPoint: String,
    fadeFromIndex: Number,
    snapToSequentialPoint: Boolean,
    closeThreshold: { type: Number, default: 0.25 },
    scrollLockTimeout: { type: Number, default: 100 },
    shouldScaleBackground: Boolean,
    setBackgroundColorOnScale: { type: Boolean, default: true },
    noBodyStyles: Boolean,
    fixed: Boolean,
    nested: Boolean,
    disablePreventScroll: { type: Boolean, default: true },
    preventScrollRestoration: Boolean,
    repositionInputs: { type: Boolean, default: true },
    container: String
  }

  // Same host marker as the sheet: only the templates of this host and this drawer are ours.
  templates() {
    return [...this.element.querySelectorAll("template[data-chadcn--dialog-template]")].filter(
      (template) =>
        template.getAttribute("data-chadcn--dialog-template") === this.idValue &&
        template.closest("[data-controller~='chadcn--drawer']") === this.element
    )
  }

  connect() {
    this.ready = false
    this.timers = new Set()
    this.bound = new Map()
    this.hasBeenOpened = false
    this.isDragging = false
    this.justReleased = false
    this.isAllowedToDrag = false
    this.keyboardIsOpen = false
    this.openTime = null
    this.dragStartTime = null
    this.lastTimeDragPrevented = null
    this.pointerStart = 0
    this.previousDiffFromInitial = 0
    this.initialDrawerHeight = 0
    this.drawerHeight = 0
    this.drawerWidth = 0
    this.vaulOpen = this.openValue
    // vaul: shouldAnimate = !defaultOpen; a controlled open is not a defaultOpen.
    this.shouldAnimate = this.controlledValue || !this.openValue
    this.activeSnap = this.snapPoints[0]
    this.cleanups = []
    this.scrollPosition = window.scrollY

    super.connect()
    this.ready = true

    requestAnimationFrame(() => (this.shouldAnimate = true))
    if (!this.vaulModalValue) requestAnimationFrame(() => (document.body.style.pointerEvents = "auto"))
    this.#listen(window, "scroll", () => (this.scrollPosition = window.scrollY))
    this.#listen(window, "resize", () => this.#onResize())
    if (window.visualViewport) this.#listen(window.visualViewport, "resize", () => this.#onVisualViewportChange())
    this.#openEffects()
    this.#reconcile()
    this.#paint()
  }

  disconnect() {
    this.ready = false
    this.timers.forEach((id) => clearTimeout(id))
    this.timers.clear()
    this.#closeEffects()
    this.bound.forEach((entry) => entry.abort.abort())
    this.bound.clear()
    this.cleanups.forEach((cleanup) => cleanup())
    this.cleanups = []
    super.disconnect()
  }

  // The dismissible guard of vaul's onOpenChange (vaul:1343-1351), then Radix's own request.
  request(next) {
    if (next === this.openValue) return
    if (!next && !this.dismissibleValue) return
    if (next) this.hasBeenOpened = true
    else this.#closeDrawer(true)
    this.#setOpen(next)
  }

  openValueChanged() {
    if (!this.ready) return super.openValueChanged()
    this.#paint(this.openValue)
    super.openValueChanged()
    this.#afterChange()
  }

  activeSnapPointValueChanged() {
    if (!this.ready) return
    this.#paint()
    this.#snapEffect()
  }

  // vaul gives Radix callbacks that decide after the public event has run: preventing here keeps `defaultPrevented` false for the
  // listeners and true for the dialog controller that reads the event it just dispatched.
  dispatch(name, options) {
    const event = super.dispatch(name, options)
    const prevented =
      (name === "open-auto-focus" && !this.autoFocusValue) ||
      ((name === "pointer-down-outside" || name === "focus-outside") && !this.vaulModalValue) ||
      (name === "pointer-down-outside" && this.#isRightClick(options?.detail?.originalEvent))
    if (prevented) event.preventDefault()
    return event
  }

  // Radix DialogContent onPointerDownOutside (dialog:178-183): a right or ctrl+left press outside never dismisses a modal dialog.
  #isRightClick(event) {
    return event?.button === 2 || (event?.button === 0 && event.ctrlKey === true)
  }

  // --- open state --------------------------------------------------------------------------------------------------------------------

  #setOpen(next) {
    if (next === this.openValue) return
    // Presence reads the animation name when the exit starts: the vaul attributes have to be those of the render that closes.
    if (!this.controlledValue) this.#paint(next)
    super.request(next)
    // vaul's onChange runs on the request when controlled (the state does not change), from the state change otherwise.
    if (this.controlledValue) this.#onOpenChange(next)
    this.#afterChange()
  }

  #afterChange() {
    this.#reconcile()
    if (this.vaulOpen !== this.openValue) {
      const open = this.openValue
      this.vaulOpen = open
      if (!this.controlledValue) this.#onOpenChange(open)
      open ? this.#openEffects() : this.#closeEffects()
    }
    this.#paint()
  }

  // The onChange of vaul's Root useControllableState (vaul:884-903).
  #onOpenChange(open) {
    if (!open && !this.nestedValue) this.#restorePositionSetting()
    this.#later(() => this.dispatch("animation-end", { detail: { open } }), TRANSITION_MS)
    if (open && !this.vaulModalValue) requestAnimationFrame(() => (document.body.style.pointerEvents = "auto"))
    if (!open) document.body.style.pointerEvents = "auto"
  }

  // The effects vaul keys on isOpen.
  #openEffects() {
    if (!this.vaulOpen) return
    this.htmlScrollBehavior = document.documentElement.style.scrollBehavior
    document.documentElement.style.scrollBehavior = "auto"
    this.openTime = new Date()
    this.#scaleBackground()
    this.#positionFixed()
    this.#syncPreventScroll()
  }

  #closeEffects() {
    if (this.htmlScrollBehavior !== undefined) document.documentElement.style.scrollBehavior = this.htmlScrollBehavior
    this.htmlScrollBehavior = undefined
    this.scaleCleanup?.()
    this.scaleCleanup = null
    this.#syncPreventScroll()
    this.#positionFixed()
  }

  // --- parts -------------------------------------------------------------------------------------------------------------------------

  get content() {
    return this.parts.findLast((part) => part.kind === "content")?.el
  }

  get overlay() {
    return this.parts.findLast((part) => part.kind === "overlay")?.el
  }

  get direction() {
    return this.directionValue
  }

  #reconcile() {
    this.bound.forEach((entry, part) => {
      if (this.parts.includes(part)) return
      entry.abort.abort()
      this.bound.delete(part)
    })
    this.parts.forEach((part) => {
      if (!this.bound.has(part)) this.#bind(part)
    })
  }

  #bind(part) {
    const abort = new AbortController()
    this.bound.set(part, { abort })
    const on = (type, handler) => part.el.addEventListener(type, handler, { signal: abort.signal })
    if (part.kind === "overlay") {
      on("mouseup", (event) => this.#onRelease(event))
    } else if (part.kind === "content") {
      this.#bindContent(part, on)
    }
  }

  #bindContent(part, on) {
    part.pointerStart = null
    part.lastPointerEvent = null
    part.wasBeyondThePoint = false
    part.delayed = false
    this.snapEffectDone = false
    if (this.hasSnapPoints) {
      requestAnimationFrame(() => {
        if (!this.parts.includes(part)) return
        part.delayed = true
        this.#paint()
      })
    }

    const release = (event) => {
      part.pointerStart = null
      part.wasBeyondThePoint = false
      this.#onRelease(event)
    }
    on("pointerdown", (event) => {
      if (this.handleOnlyValue) return
      part.pointerStart = { x: event.pageX, y: event.pageY }
      this.#onPress(event)
    })
    on("pointermove", (event) => {
      part.lastPointerEvent = event
      if (this.handleOnlyValue || !part.pointerStart) return
      const delta = { x: event.pageX - part.pointerStart.x, y: event.pageY - part.pointerStart.y }
      const threshold = event.pointerType === "touch" ? 10 : 2
      if (this.#isDeltaInDirection(part, delta, threshold)) this.#onDrag(event)
      else if (Math.abs(delta.x) > threshold || Math.abs(delta.y) > threshold) part.pointerStart = null
    })
    on("pointerup", (event) => release(event))
    on("pointerout", () => release(part.lastPointerEvent))
    on("contextmenu", () => {
      if (part.lastPointerEvent) release(part.lastPointerEvent)
    })
  }

  #isDeltaInDirection(part, delta, threshold) {
    if (part.wasBeyondThePoint) return true
    const deltaX = Math.abs(delta.x)
    const deltaY = Math.abs(delta.y)
    const factor = ["bottom", "right"].includes(this.direction) ? 1 : -1
    if (isVertical(this.direction)) {
      if (!(delta.y * factor < 0) && deltaY <= threshold) return !(deltaX > deltaY)
    } else if (!(delta.x * factor < 0) && deltaX <= threshold) {
      return deltaX > deltaY
    }
    part.wasBeyondThePoint = true
    return true
  }

  // What React would re-render on the Root's props and state: the vaul attributes of Overlay and Content (vaul:1387-1466).
  #paint(open = this.openValue) {
    if (!this.parts) return
    const snapActive = open && this.hasSnapPoints
    this.parts.forEach((part) => {
      if (part.kind === "overlay") {
        part.el.setAttribute("data-vaul-snap-points", bool(snapActive))
        part.el.setAttribute("data-vaul-snap-points-overlay", bool(open && this.shouldFade))
        part.el.setAttribute("data-vaul-animate", bool(this.shouldAnimate))
      } else if (part.kind === "content") {
        part.el.setAttribute("data-vaul-snap-points", bool(snapActive))
        part.el.setAttribute("data-vaul-delayed-snap-points", bool(part.delayed))
        part.el.setAttribute("data-vaul-animate", bool(this.shouldAnimate))
        const offsets = this.snapPointsOffset
        if (offsets.length > 0) part.el.style.setProperty("--snap-point-height", `${offsets[this.activeSnapPointIndex ?? 0]}px`)
      }
    })
  }

  // --- gesture -----------------------------------------------------------------------------------------------------------------------

  #onPress(event) {
    if (!this.dismissibleValue && !this.hasSnapPoints) return
    const content = this.content
    if (content && !content.contains(event.target)) return
    this.drawerHeight = content?.getBoundingClientRect().height || 0
    this.drawerWidth = content?.getBoundingClientRect().width || 0
    this.#setDragging(true)
    this.dragStartTime = new Date()
    if (isIOS()) window.addEventListener("touchend", () => (this.isAllowedToDrag = false), { once: true })
    event.target.setPointerCapture(event.pointerId)
    this.pointerStart = isVertical(this.direction) ? event.pageY : event.pageX
  }

  // vaul re-renders the Root on isDragging / justReleased: attributes, preventScroll and, for the first render with a mounted
  // Content, the snap effect (the callback identity changes with drawerRef.current).
  #setDragging(value) {
    if (this.isDragging === value) return
    this.isDragging = value
    this.#paint()
    this.#syncPreventScroll()
    if (value && !this.snapEffectDone) this.#snapEffect()
    if (value) this.snapEffectDone = true
  }

  #shouldDrag(el, isDraggingInDirection) {
    const content = this.content
    const highlightedText = window.getSelection()?.toString()
    const swipeAmount = content ? getTranslate(content, this.direction) : null
    const now = new Date()
    if (el.tagName === "SELECT") return false
    if (el.hasAttribute("data-vaul-no-drag") || el.closest("[data-vaul-no-drag]")) return false
    if (this.direction === "right" || this.direction === "left") return true
    if (this.openTime && now - this.openTime < 500) return false
    if (swipeAmount !== null && (this.direction === "bottom" ? swipeAmount > 0 : swipeAmount < 0)) return true
    if (highlightedText && highlightedText.length > 0) return false
    if (this.lastTimeDragPrevented && now - this.lastTimeDragPrevented < this.scrollLockTimeoutValue && swipeAmount === 0) {
      this.lastTimeDragPrevented = now
      return false
    }
    if (isDraggingInDirection) {
      this.lastTimeDragPrevented = now
      return false
    }
    let element = el
    while (element) {
      if (element.scrollHeight > element.clientHeight) {
        if (element.scrollTop !== 0) {
          this.lastTimeDragPrevented = new Date()
          return false
        }
        if (element.getAttribute?.("role") === "dialog") return true
      }
      element = element.parentNode
    }
    return true
  }

  #onDrag(event) {
    const content = this.content
    if (!content || !this.isDragging) return
    const direction = this.direction
    const multiplier = direction === "bottom" || direction === "right" ? 1 : -1
    const draggedDistance = (this.pointerStart - (isVertical(direction) ? event.pageY : event.pageX)) * multiplier
    const isDraggingInDirection = draggedDistance > 0
    const noCloseSnapPoints = this.hasSnapPoints && !this.dismissibleValue && !isDraggingInDirection
    if (noCloseSnapPoints && this.activeSnapPointIndex === 0) return

    const absDraggedDistance = Math.abs(draggedDistance)
    const wrapper = document.querySelector(WRAPPER)
    const dimension = isVertical(direction) ? this.drawerHeight : this.drawerWidth
    let percentageDragged = absDraggedDistance / dimension
    const snapPercentage = this.#snapPercentageDragged(absDraggedDistance, isDraggingInDirection)
    if (snapPercentage !== null) percentageDragged = snapPercentage
    if (noCloseSnapPoints && percentageDragged >= 1) return
    if (!this.isAllowedToDrag && !this.#shouldDrag(event.target, isDraggingInDirection)) return

    content.classList.add(DRAG_CLASS)
    this.isAllowedToDrag = true
    set(content, { transition: "none" })
    set(this.overlay, { transition: "none" })
    if (this.hasSnapPoints) this.#snapDrag(draggedDistance)

    if (isDraggingInDirection && !this.hasSnapPoints) {
      const translate = Math.min(dampenValue(draggedDistance) * -1, 0) * multiplier
      set(content, { transform: translate3d(direction, translate) })
      return
    }

    const fadeIndex = this.hasFadeFromIndexValue ? this.fadeFromIndexValue : undefined
    if (this.shouldFade || (fadeIndex && this.activeSnapPointIndex === fadeIndex - 1)) {
      this.dispatch("drag", { detail: { originalEvent: event, percentageDragged } })
      set(this.overlay, { opacity: `${1 - percentageDragged}`, transition: "none" })
    }
    if (wrapper && this.overlay && this.shouldScaleBackgroundValue) {
      const scale = Math.min(this.#scale() + percentageDragged * (1 - this.#scale()), 1)
      const radius = BORDER_RADIUS - percentageDragged * BORDER_RADIUS
      const shift = Math.max(0, 14 - percentageDragged * 14)
      set(wrapper, {
        borderRadius: `${radius}px`,
        transform: isVertical(direction) ? `scale(${scale}) translate3d(0, ${shift}px, 0)` : `scale(${scale}) translate3d(${shift}px, 0, 0)`,
        transition: "none"
      })
    }
    if (!this.hasSnapPoints) set(content, { transform: translate3d(direction, absDraggedDistance * multiplier) })
  }

  #onRelease(event) {
    const content = this.content
    if (!this.isDragging || !content) return
    content.classList.remove(DRAG_CLASS)
    this.isAllowedToDrag = false
    this.#setDragging(false)
    const dragEndTime = new Date()
    const swipeAmount = getTranslate(content, this.direction)
    if (!event || !this.#shouldDrag(event.target, false) || !swipeAmount || Number.isNaN(swipeAmount)) return
    if (this.dragStartTime === null) return

    const direction = this.direction
    const distMoved = this.pointerStart - (isVertical(direction) ? event.pageY : event.pageX)
    const velocity = Math.abs(distMoved) / (dragEndTime - this.dragStartTime)
    if (velocity > 0.05) {
      this.justReleased = true
      this.#syncPreventScroll()
      this.#later(() => {
        this.justReleased = false
        this.#syncPreventScroll()
      }, 200)
    }

    const release = (open) => this.dispatch("release", { detail: { originalEvent: event, open } })
    if (this.hasSnapPoints) {
      const multiplier = direction === "bottom" || direction === "right" ? 1 : -1
      this.#snapRelease({ draggedDistance: distMoved * multiplier, velocity })
      release(true)
      return
    }
    if (direction === "bottom" || direction === "right" ? distMoved > 0 : distMoved < 0) {
      this.#resetDrawer()
      release(true)
      return
    }
    if (velocity > VELOCITY_THRESHOLD) {
      this.#closeDrawer(false)
      release(false)
      return
    }
    const rect = content.getBoundingClientRect()
    const visible = isVertical(direction) ? Math.min(rect.height ?? 0, window.innerHeight) : Math.min(rect.width ?? 0, window.innerWidth)
    if (Math.abs(swipeAmount) >= visible * this.closeThresholdValue) {
      this.#closeDrawer(false)
      release(false)
      return
    }
    release(true)
    this.#resetDrawer()
  }

  #cancelDrag() {
    const content = this.content
    if (!this.isDragging || !content) return
    content.classList.remove(DRAG_CLASS)
    this.isAllowedToDrag = false
    this.#setDragging(false)
  }

  #resetDrawer() {
    const content = this.content
    if (!content) return
    const wrapper = document.querySelector(WRAPPER)
    const swipe = getTranslate(content, this.direction)
    set(content, { transform: "translate3d(0, 0, 0)", transition: transitionOf("transform") })
    set(this.overlay, { transition: transitionOf("opacity"), opacity: "1" })
    if (this.shouldScaleBackgroundValue && swipe && swipe > 0 && this.openValue) {
      const vertical = isVertical(this.direction)
      set(wrapper, {
        borderRadius: `${BORDER_RADIUS}px`,
        overflow: "hidden",
        transform: vertical
          ? `scale(${this.#scale()}) translate3d(0, calc(env(safe-area-inset-top) + 14px), 0)`
          : `scale(${this.#scale()}) translate3d(calc(env(safe-area-inset-top) + 14px), 0, 0)`,
        transformOrigin: vertical ? "top" : "left",
        transitionProperty: "transform, border-radius",
        transitionDuration: `${DURATION}s`,
        transitionTimingFunction: EASE
      })
    }
  }

  // vaul closeDrawer (vaul:1173-1184): `fromWithin` is the path through the Radix onOpenChange, which then sets the state itself.
  #closeDrawer(fromWithin) {
    this.#cancelDrag()
    this.dispatch("close")
    if (!fromWithin) this.#setOpen(false)
    this.#later(() => {
      if (this.hasSnapPoints) this.#setActiveSnapPoint(this.snapPoints[0])
    }, TRANSITION_MS)
  }

  // --- snap points (vaul:508-712) ------------------------------------------------------------------------------------------------------

  get snapPoints() {
    return this.snapPointsValue
  }

  get hasSnapPoints() {
    return this.snapPoints.length > 0
  }

  get controlledSnap() {
    return this.hasActiveSnapPointValue
  }

  get activeSnapPoint() {
    if (!this.hasSnapPoints) return undefined
    if (!this.controlledSnap) return this.activeSnap
    return this.snapPoints.find((point) => String(point) === this.activeSnapPointValue || Number(point) === Number(this.activeSnapPointValue))
  }

  get activeSnapPointIndex() {
    if (!this.hasSnapPoints) return null
    return this.snapPoints.findIndex((point) => point === this.activeSnapPoint)
  }

  get fadeFromIndex() {
    if (this.hasFadeFromIndexValue) return this.fadeFromIndexValue
    return this.hasSnapPoints ? this.snapPoints.length - 1 : undefined
  }

  get shouldFade() {
    if (!this.hasSnapPoints) return true
    const index = this.fadeFromIndex
    return (Boolean(index) || index === 0) && !Number.isNaN(index) && this.snapPoints[index] === this.activeSnapPoint
  }

  get snapPointsOffset() {
    if (!this.hasSnapPoints) return []
    const container = this.containerValue && document.querySelector(this.containerValue)
    const size = container ? container.getBoundingClientRect() : { width: window.innerWidth, height: window.innerHeight }
    return this.snapPoints.map((point) => {
      const isPx = typeof point === "string"
      const px = isPx ? parseInt(point, 10) : 0
      if (isVertical(this.direction)) {
        const height = isPx ? px : point * size.height
        return this.direction === "bottom" ? size.height - height : -size.height + height
      }
      const width = isPx ? px : point * size.width
      return this.direction === "right" ? size.width - width : -size.width + width
    })
  }

  // useControllableState for the active snap point: controlled only reports, uncontrolled also changes.
  #setActiveSnapPoint(value) {
    if (this.controlledSnap) {
      if (value !== this.activeSnapPoint) this.dispatch("active-snap-point-change", { detail: { activeSnapPoint: value } })
      return
    }
    if (value === this.activeSnap) return
    this.activeSnap = value
    this.dispatch("active-snap-point-change", { detail: { activeSnapPoint: value } })
    this.#paint()
    this.#snapEffect()
  }

  // The useEffect of useSnapPoints: re-applies the offset of the active point.
  #snapEffect() {
    if (!this.hasSnapPoints || !this.activeSnapPoint) return
    const index = this.activeSnapPointIndex
    const offsets = this.snapPointsOffset
    if (index !== -1 && typeof offsets[index] === "number") this.#snapToPoint(offsets[index])
  }

  #snapToPoint(dimension) {
    const offsets = this.snapPointsOffset
    const index = offsets.findIndex((offset) => offset === dimension)
    if (this.hasSnapPoints && index === offsets.length - 1) this.openTime = new Date()
    set(this.content, { transition: transitionOf("transform"), transform: translate3d(this.direction, dimension) })
    const fadeIndex = this.fadeFromIndex
    if (index !== offsets.length - 1 && fadeIndex !== undefined && index !== fadeIndex && index < fadeIndex) {
      set(this.overlay, { transition: transitionOf("opacity"), opacity: "0" })
    } else {
      set(this.overlay, { transition: transitionOf("opacity"), opacity: "1" })
    }
    this.#setActiveSnapPoint(this.snapPoints[Math.max(index, 0)])
  }

  #snapRelease({ draggedDistance, velocity }) {
    if (this.fadeFromIndex === undefined) return
    const { direction } = this
    const offsets = this.snapPointsOffset
    const activeOffset = offsets[this.activeSnapPointIndex] ?? 0
    const currentPosition = direction === "bottom" || direction === "right" ? activeOffset - draggedDistance : activeOffset + draggedDistance
    const isOverlaySnapPoint = this.activeSnapPointIndex === this.fadeFromIndex - 1
    const isFirst = this.activeSnapPointIndex === 0
    const hasDraggedUp = draggedDistance > 0
    const lastIndex = this.snapPoints.length - 1
    const isLast = this.activeSnapPoint === this.snapPoints[lastIndex]
    const sequential = this.snapToSequentialPointValue
    if (isOverlaySnapPoint) set(this.overlay, { transition: transitionOf("opacity") })

    if (!sequential && velocity > 2 && !hasDraggedUp) {
      if (this.dismissibleValue) this.#closeDrawer(false)
      else this.#snapToPoint(offsets[0])
      return
    }
    if (!sequential && velocity > 2 && hasDraggedUp) {
      this.#snapToPoint(offsets[lastIndex])
      return
    }
    const closest = offsets.reduce((previous, current) =>
      Math.abs(current - currentPosition) < Math.abs(previous - currentPosition) ? current : previous
    )
    const dimension = isVertical(direction) ? window.innerHeight : window.innerWidth
    if (velocity > VELOCITY_THRESHOLD && Math.abs(draggedDistance) < dimension * 0.4) {
      const dragDirection = hasDraggedUp ? 1 : -1
      if (dragDirection > 0 && isLast) {
        this.#snapToPoint(offsets[lastIndex])
        return
      }
      if (isFirst && dragDirection < 0 && this.dismissibleValue) this.#closeDrawer(false)
      if (this.activeSnapPointIndex === null) return
      this.#snapToPoint(offsets[this.activeSnapPointIndex + dragDirection])
      return
    }
    this.#snapToPoint(closest)
  }

  #snapDrag({ draggedDistance }) {
    const offsets = this.snapPointsOffset
    const activeOffset = offsets[this.activeSnapPointIndex]
    if (activeOffset === null || activeOffset === undefined) return
    const { direction } = this
    const value = direction === "bottom" || direction === "right" ? activeOffset - draggedDistance : activeOffset + draggedDistance
    const last = offsets[offsets.length - 1]
    if ((direction === "bottom" || direction === "right") && value < last) return
    if ((direction === "top" || direction === "left") && value > last) return
    set(this.content, { transform: translate3d(direction, value) })
  }

  #snapPercentageDragged(absDraggedDistance, isDraggingDown) {
    const index = this.activeSnapPointIndex
    const fadeIndex = this.fadeFromIndex
    const offsets = this.snapPointsOffset
    if (!this.hasSnapPoints || typeof index !== "number" || fadeIndex === undefined) return null
    const isOverlaySnapPoint = index === fadeIndex - 1
    const isOverlaySnapPointOrHigher = index >= fadeIndex
    if (isOverlaySnapPointOrHigher && isDraggingDown) return 0
    if (isOverlaySnapPoint && !isDraggingDown) return 1
    if (!this.shouldFade && !isOverlaySnapPoint) return null
    const target = isOverlaySnapPoint ? index + 1 : index - 1
    const distance = isOverlaySnapPoint ? offsets[target] - offsets[target - 1] : offsets[target + 1] - offsets[target]
    const percentage = absDraggedDistance / Math.abs(distance)
    return isOverlaySnapPoint ? 1 - percentage : percentage
  }

  #onResize() {
    this.#paint()
    if (this.hasSnapPoints) this.#snapEffect()
  }

  // --- background, body and keyboard ------------------------------------------------------------------------------------------------------

  #scale() {
    return (window.innerWidth - WINDOW_TOP_OFFSET) / window.innerWidth
  }

  // useScaleBackground (vaul:714-760). The first assignStyle pair is never undone by vaul (its chain() result is not called).
  #scaleBackground() {
    if (!this.shouldScaleBackgroundValue) return
    clearTimeout(this.backgroundTimer)
    const wrapper = document.querySelector(WRAPPER)
    if (!wrapper) return
    const vertical = isVertical(this.direction)
    if (this.setBackgroundColorOnScaleValue && !this.noBodyStylesValue) {
      this.initialBackground ??= document.body.style.backgroundColor
      assignStyle(document.body, { background: "black" })
    }
    assignStyle(wrapper, {
      transformOrigin: vertical ? "top" : "left",
      transitionProperty: "transform, border-radius",
      transitionDuration: `${DURATION}s`,
      transitionTimingFunction: EASE
    })
    const restore = assignStyle(wrapper, {
      borderRadius: `${BORDER_RADIUS}px`,
      overflow: "hidden",
      transform: vertical
        ? `scale(${this.#scale()}) translate3d(0, calc(env(safe-area-inset-top) + 14px), 0)`
        : `scale(${this.#scale()}) translate3d(calc(env(safe-area-inset-top) + 14px), 0, 0)`
    })
    this.scaleCleanup = () => {
      restore()
      this.backgroundTimer = setTimeout(() => {
        if (this.initialBackground) document.body.style.background = this.initialBackground
        else document.body.style.removeProperty("background")
      }, TRANSITION_MS)
      this.timers.add(this.backgroundTimer)
    }
  }

  // usePositionFixed (vaul:762-877).
  #positionFixed() {
    if (this.nestedValue || !this.hasBeenOpened) return
    if (this.vaulOpen) {
      if (!window.matchMedia("(display-mode: standalone)").matches) this.#setPositionFixed()
      if (!this.vaulModalValue) this.#later(() => this.#restorePositionSetting(), 500)
    } else {
      this.#restorePositionSetting()
    }
  }

  #setPositionFixed() {
    if (!isSafari()) return
    if (previousBodyPosition !== null || !this.vaulOpen || this.noBodyStylesValue) return
    const { style } = document.body
    previousBodyPosition = { position: style.position, top: style.top, left: style.left, height: style.height, right: "unset" }
    const { scrollX, innerHeight } = window
    style.setProperty("position", "fixed", "important")
    Object.assign(style, { top: `${-this.scrollPosition}px`, left: `${-scrollX}px`, right: "0px", height: "auto" })
    this.#later(
      () =>
        requestAnimationFrame(() => {
          const bottomBarHeight = innerHeight - window.innerHeight
          if (bottomBarHeight && this.scrollPosition >= innerHeight) style.top = `${-(this.scrollPosition + bottomBarHeight)}px`
        }),
      300
    )
  }

  #restorePositionSetting() {
    if (!isSafari() || previousBodyPosition === null || this.noBodyStylesValue) return
    const y = -parseInt(document.body.style.top, 10)
    const x = -parseInt(document.body.style.left, 10)
    Object.assign(document.body.style, previousBodyPosition)
    const url = window.location.href
    requestAnimationFrame(() => {
      if (this.preventScrollRestorationValue && url !== window.location.href) return
      window.scrollTo(x, y)
    })
    previousBodyPosition = null
  }

  // usePreventScroll (vaul:158-185): iOS only, counted across drawers.
  #syncPreventScroll() {
    const disabled =
      !this.vaulOpen || this.isDragging || !this.vaulModalValue || this.justReleased || !this.hasBeenOpened || !this.repositionInputsValue || !this.disablePreventScrollValue
    if (disabled === !this.preventingScroll) return
    this.preventingScroll = !disabled
    if (this.preventingScroll) {
      preventScrollCount += 1
      if (preventScrollCount === 1 && isIOS()) restorePreventScroll = preventScrollMobileSafari()
    } else {
      preventScrollCount -= 1
      if (preventScrollCount === 0) restorePreventScroll?.()
    }
  }

  // The visualViewport handler of Root (vaul:1112-1172): keeps the focused input above the keyboard.
  #onVisualViewportChange() {
    const content = this.content
    if (!content || !this.repositionInputsValue) return
    if (!isInput(document.activeElement) && !this.keyboardIsOpen) return
    const viewportHeight = window.visualViewport?.height || 0
    const totalHeight = window.innerHeight
    let diffFromInitial = totalHeight - viewportHeight
    const drawerHeight = content.getBoundingClientRect().height || 0
    const isTallEnough = drawerHeight > totalHeight * 0.8
    if (!this.initialDrawerHeight) this.initialDrawerHeight = drawerHeight
    const offsetFromTop = content.getBoundingClientRect().top
    if (Math.abs(this.previousDiffFromInitial - diffFromInitial) > 60) this.keyboardIsOpen = !this.keyboardIsOpen
    if (this.hasSnapPoints && this.activeSnapPointIndex) diffFromInitial += this.snapPointsOffset[this.activeSnapPointIndex] || 0
    this.previousDiffFromInitial = diffFromInitial

    if (drawerHeight > viewportHeight || this.keyboardIsOpen) {
      const height = content.getBoundingClientRect().height
      let newHeight = height
      if (height > viewportHeight) newHeight = viewportHeight - (isTallEnough ? offsetFromTop : WINDOW_TOP_OFFSET)
      if (this.fixedValue) content.style.height = `${height - Math.max(diffFromInitial, 0)}px`
      else content.style.height = `${Math.max(newHeight, viewportHeight - offsetFromTop)}px`
    } else if (!isMobileFirefox()) {
      content.style.height = `${this.initialDrawerHeight}px`
    }
    if (this.hasSnapPoints && !this.keyboardIsOpen) content.style.bottom = "0px"
    else content.style.bottom = `${Math.max(diffFromInitial, 0)}px`
  }

  // --- helpers -----------------------------------------------------------------------------------------------------------------------

  #listen(target, type, handler) {
    target.addEventListener(type, handler)
    this.cleanups.push(() => target.removeEventListener(type, handler))
  }

  #later(fn, ms) {
    const id = setTimeout(() => {
      this.timers.delete(id)
      fn()
    }, ms)
    this.timers.add(id)
  }
}
