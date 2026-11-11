import { Controller } from "@hotwired/stimulus"
import { activeDotElements, cursorElement } from "chadcn/primitives/chart_shapes"
import { nearestTickIndex, pointerInPlot, relativePointer } from "chadcn/primitives/chart_pointer"
import { chartInResponse, laidOutAt, observeSettledSize, relayoutNeeded, relayoutRequestUrl, scaleToBox } from "chadcn/primitives/chart_relayout"
import { SIDE_CLASSES, tooltipPlacement } from "chadcn/primitives/chart_tooltip_placement"
import { mountTemplate } from "chadcn/primitives/template_mount"
import { turboCacheRestore } from "chadcn/primitives/turbo_cache"

// recharts' tooltip interaction (Tooltip + Cursor + ActivePoints + the accessibility layer) on a server-rendered chart. Spec:
// dev/port/specs/chart.md ("Tooltip", "Behavior"). Nothing is drawn here: the server ships one inert <template> per tooltip index and
// this controller mounts the one for the active index into `.recharts-tooltip-wrapper`, draws the cursor and the active dots from the
// template's JSON and positions the wrapper with recharts' own algorithm.
//
// Three interactions are independent states (`state/selectors/combiners/combineTooltipInteractionState.js:22-58`): the pointer's, the
// keyboard's and `default_index`. The tooltip shows the pointer index while the pointer is active, else the keyboard index while the
// keyboard is active, else `default_index` only while the pointer has never activated an index. The states are the values
// (pointerIndex/pointerActive/keyboardIndex/keyboardActive); only the pointer's last coordinate and the Escape dismissal are kept
// outside them, and both are handed over a Turbo cache round trip.
//
// With a `relayoutUrl` the chart follows the size of its element ("Behavior", "Resize and re-measure"): once the box has settled at
// another size than the server drew, the controller requests the chart from that same-origin URL at the measured size, swaps the
// answer in and hands it the interaction state. This is the recorded exception to stimulus R1 and R6 (.ai/skills/stimulus/SKILL.md):
// only this controller fetches HTML, only its own chart from its own `relayoutUrl`, and it reads recharts nodes by class.
const ARROWS = { ArrowRight: 1, ArrowLeft: -1 }
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"
const EVENT_ACTIVATE = "activate"
const EVENT_DEACTIVATE = "deactivate"
// The z-index layer of the active dots: DefaultZIndexes.activeDot (recharts es6/zIndex/DefaultZIndexes.js:68).
const ACTIVE_DOT_LAYER = 1200
const EVENT_RELAYOUT = "relayout"
const EVENT_RELAYOUT_ERROR = "relayout-error"
// The interaction values a re-laid-out chart takes over from the one it replaces.
const CARRIED_VALUES = { pointerIndex: "pointer-index", pointerActive: "pointer-active", keyboardIndex: "keyboard-index", keyboardActive: "keyboard-active" }
// The server state of a swapped-in chart (what its answer said before the live state was carried over), for its Turbo snapshot.
const SERVED_STATES = new WeakMap()

export default class extends Controller {
  static targets = ["surface", "tooltip", "tooltipTemplate", "cursor", "activeDots"]

  static values = {
    layout: { type: String, default: "horizontal" },
    keyboardStep: { type: Number, default: 1 },
    accessibilityLayer: { type: Boolean, default: true },
    ticks: { type: Array, default: [] },
    plot: { type: Object, default: {} },
    pointerIndex: { type: Number, default: -1 },
    pointerActive: { type: Boolean, default: false },
    keyboardIndex: { type: Number, default: -1 },
    keyboardActive: { type: Boolean, default: false },
    defaultIndex: { type: Number, default: -1 },
    tooltipEventType: { type: String, default: "axis" },
    trigger: { type: String, default: "hover" },
    tooltipActive: { type: String, default: "" },
    offset: { type: Object, default: { x: 10, y: 10 } },
    allowEscape: { type: Object, default: { x: false, y: false } },
    reverseDirection: { type: Object, default: { x: false, y: false } },
    position: { type: Object, default: {} },
    transition: { type: String, default: "" },
    transitionAuto: { type: Boolean, default: false },
    wrapperStyle: { type: Object, default: {} },
    relayoutUrl: { type: String, default: "" },
    dimension: { type: Object, default: {} },
    textMetrics: { type: Object, default: {} },
  }

  connect() {
    this.shownIndex = null
    this.announcing = true
    this.mounted = null
    this.pointerCoordinate = null
    this.dismissedAt = null
    this.activeCoordinate = null
    this.serverState = SERVED_STATES.get(this.element) ?? this.interactionState()
    this.relayoutStopped = false
    this.cache = turboCacheRestore({
      teardown: (cancelled) => this.resetToServerState(cancelled),
      // The restore observes the box again, which checks its size once more (the teardown stopped the re-layout).
      restore: (live) => {
        this.applyState(live)
        this.startRelayout()
      },
    })
    this.render()
    this.startRelayout()
  }

  disconnect() {
    this.stopRelayout()
    this.cache?.release()
    this.cache = null
    // A re-inserted element starts from the server state: no interaction values, no content, a hidden wrapper.
    this.writeInteraction(this.serverState)
    // An inert controller (an item tooltip, no tooltip) never touched the DOM, so it leaves the server-drawn tooltip alone.
    if (!this.interactive) return

    this.clearContent()
    this.tooltipTarget.style.visibility = "hidden"
  }

  // --- actions (data-action on .recharts-wrapper, rendered by the Phlex chart) -------------------------------------------------

  // `pointermove` and touch: recharts `mouseMoveAction` / `touchMoveAction` (`state/mouseEventsMiddleware.js:38-110`,
  // `state/touchEventsMiddleware.js:43-64`). A mouse outside the plot clears the hover (`mouseEventsMiddleware.js:90-93`), a touch
  // outside does nothing (the `activeIndex != null` guard, `touchEventsMiddleware.js:57-64`).
  move(event) {
    if (!this.listening || this.triggerValue !== "hover") return

    this.activateFromPointer(event, { leaveOutside: event.pointerType !== "touch" })
  }

  // `click`: the click interaction of recharts (`state/mouseEventsMiddleware.js:10-23`), the one a `trigger: click` tooltip follows
  // (`chooseAppropriateMouseInteraction`, `combineTooltipInteractionState.js:7-18`).
  click(event) {
    if (!this.listening || this.triggerValue !== "click") return

    this.activateFromPointer(event, { leaveOutside: false })
  }

  // `mouseLeaveChart` clears the hover's active flag only and keeps its index (`state/tooltipSlice.js:156-166`), so `default_index`
  // never returns. The click interaction is not touched by it. A touch lifting off is not a leave: recharts has no touch end handler.
  leave(event) {
    if (!this.listening || this.triggerValue !== "hover" || event.pointerType === "touch") return

    this.pointerActiveValue = false
    this.render()
  }

  // `focus` on the chart activates category 0 unless the keyboard interaction is active or remembers an index
  // (`state/keyboardEventsMiddleware.js:103-127`).
  focus() {
    if (!this.keyboardEnabled || this.keyboardActiveValue || this.keyboardIndexValue >= 0) return

    this.keyboardIndexValue = 0
    this.keyboardActiveValue = true
    this.render()
  }

  // `blur` deactivates and remembers the index (`:128-146`).
  blur() {
    if (!this.keyboardEnabled || !this.keyboardActiveValue) return

    this.keyboardActiveValue = false
    this.render()
  }

  // ArrowRight/ArrowLeft move the remembered index by `keyboardStep` and stop at the ends, Enter toggles; nothing happens without a
  // remembered index (`:43-75`). Other keys are ignored.
  key(event) {
    if (!this.keyboardEnabled || this.keyboardIndexValue < 0) return

    if (event.key === "Enter") {
      this.keyboardActiveValue = !this.keyboardActiveValue
    } else if (Object.hasOwn(ARROWS, event.key)) {
      const next = this.keyboardIndexValue + ARROWS[event.key] * this.keyboardStepValue
      if (next < 0 || next >= this.ticksValue.length) return

      this.keyboardIndexValue = next
      this.keyboardActiveValue = true
    } else {
      return
    }
    this.render()
  }

  // Escape (keydown on the document) hides the tooltip until the active coordinate changes; the keyboard index is untouched
  // (`component/TooltipBoundingBox.js:21-50,83`).
  dismiss(event) {
    if (event.key !== "Escape" || !this.listening) return

    this.dismissedAt = this.activeCoordinate ?? { x: 0, y: 0 }
    this.render()
  }

  // --- state -------------------------------------------------------------------------------------------------------------------

  get interactive() {
    return this.hasTooltipTarget && this.tooltipEventTypeValue === "axis"
  }

  // Input is refused between `turbo:before-cache` and the snapshot tick, while the DOM is in its snapshot shape.
  get listening() {
    return this.interactive && !this.cache?.pending
  }

  get keyboardEnabled() {
    return this.listening && this.accessibilityLayerValue
  }

  interactionState() {
    return {
      pointerIndex: this.pointerIndexValue,
      pointerActive: this.pointerActiveValue,
      keyboardIndex: this.keyboardIndexValue,
      keyboardActive: this.keyboardActiveValue,
    }
  }

  activateFromPointer(event, { leaveOutside }) {
    const pointer = relativePointer(event)
    if (!pointerInPlot(pointer, this.plotValue)) {
      if (leaveOutside && this.pointerActiveValue) {
        this.pointerActiveValue = false
        this.render()
      }
      return
    }

    const horizontal = this.layoutValue === "horizontal"
    const index = nearestTickIndex(horizontal ? pointer.x : pointer.y, this.ticksValue)
    const tick = this.ticksValue.find((candidate) => candidate.index === index)
    if (!tick) return

    // `getActiveCartesianCoordinate`: the tick along the category axis, the pointer along the other (`util/getActiveCoordinate.js:8-28`).
    this.pointerCoordinate = horizontal ? { x: tick.coordinate, y: pointer.y } : { x: pointer.x, y: tick.coordinate }
    this.pointerIndexValue = index
    this.pointerActiveValue = true
    this.keyboardActiveValue = false
    this.render()
  }

  // Which index the tooltip shows and where it anchors (`combineTooltipInteractionState` + `selectActiveCoordinate`,
  // `state/selectors/selectors.js:49` for `selectActiveCoordinate`). `tooltipActive` false never shows, true keeps the last pointer index after the pointer left
  // (`Tooltip.js:129`, `combineTooltipInteractionState.js:39-45`).
  resolve() {
    if (this.tooltipActiveValue === "false") return { index: -1, coordinate: null }
    if (this.pointerActiveValue) return { index: this.pointerIndexValue, coordinate: this.pointerCoordinate }
    if (this.keyboardActiveValue) return { index: this.keyboardIndexValue, coordinate: null }
    if (this.pointerIndexValue >= 0) {
      return this.tooltipActiveValue === "true" ? { index: this.pointerIndexValue, coordinate: this.pointerCoordinate } : { index: -1, coordinate: this.pointerCoordinate }
    }
    return { index: this.defaultIndexValue, coordinate: null }
  }

  templateFor(index) {
    return index < 0 ? null : this.tooltipTemplateTargets.find((template) => Number(template.dataset.index) === index) ?? null
  }

  // --- rendering ---------------------------------------------------------------------------------------------------------------

  render() {
    if (!this.interactive) return

    const resolved = this.resolve()
    const template = this.templateFor(resolved.index)
    const index = template ? resolved.index : -1
    this.activeCoordinate = resolved.coordinate ?? (template ? this.json(template.dataset.coordinate) : null)

    this.releaseDismissal()
    this.show(index, template)
    this.place(index, template)
  }

  // Escape stays in force until the active coordinate differs from the one it was pressed at (`TooltipBoundingBox.js:46-50`).
  releaseDismissal() {
    const at = this.dismissedAt
    const now = this.activeCoordinate ?? { x: 0, y: 0 }
    if (at && (at.x !== now.x || at.y !== now.y)) this.dismissedAt = null
  }

  // Swaps the content, the cursor and the active dots when the index changes. The first render adopts what the server drew for
  // `default_index` instead of mounting it again.
  show(index, template) {
    const first = this.shownIndex === null
    if (index === this.shownIndex) return

    const previous = this.shownIndex
    this.shownIndex = index
    if (first && index === this.defaultIndexValue && this.tooltipTarget.childElementCount > 0) return

    this.clearContent()
    if (!template) return previous !== null && previous >= 0 ? this.announce(EVENT_DEACTIVATE, previous) : undefined

    this.mounted = mountTemplate(template, { into: this.tooltipTarget })
    this.drawShapes(template)
    this.announce(EVENT_ACTIVATE, index, template)
  }

  clearContent() {
    this.mounted?.unmount()
    this.mounted = null
    if (this.hasTooltipTarget) this.tooltipTarget.replaceChildren()
    this.cursorTargets.forEach((node) => node.remove())
    this.activeDotsTargets.forEach((node) => node.remove())
  }

  drawShapes(template) {
    const cursor = this.json(template.dataset.cursor)
    const cursorNode = cursor && cursorElement(cursor)
    if (cursorNode) this.layer(cursor.layer)?.append(this.tagged(cursorNode, "cursor"))

    const dots = activeDotElements(this.json(template.dataset.activeDots))
    dots.forEach((dot) => this.layer(ACTIVE_DOT_LAYER)?.append(this.tagged(dot, "activeDots")))
  }

  tagged(node, target) {
    node.setAttribute(`data-${this.identifier}-target`, target)
    return node
  }

  // The z-index layer group of the svg (`g.recharts-zIndex-layer_<z>`), found by class list so a layer number is never a selector.
  layer(z) {
    if (!this.hasSurfaceTarget) return null

    return [...this.surfaceTarget.children].find((child) => child.classList.contains(`recharts-zIndex-layer_${z}`)) ?? null
  }

  json(text) {
    if (!text) return null
    try {
      return JSON.parse(text)
    } catch {
      return null
    }
  }

  // The wrapper: visibility, the translate, the side classes and the transition of `TooltipBoundingBox`
  // (`component/TooltipBoundingBox.js:51-84`); `wrapperStyle` is applied last and wins (`:84`).
  place(index, template) {
    const wrapper = this.tooltipTarget
    const active = index >= 0
    const hasPayload = Boolean(template) && template.content.childElementCount > 0
    const box = wrapper.getBoundingClientRect()
    const placement = tooltipPlacement({
      coordinate: this.activeCoordinate,
      box,
      viewBox: this.plotValue,
      offset: this.offsetValue,
      position: this.positionValue,
      allowEscapeViewBox: this.allowEscapeValue,
      reverseDirection: this.reverseDirectionValue,
    })

    wrapper.classList.remove(...SIDE_CLASSES)
    wrapper.classList.add(...placement.classes)
    wrapper.style.transition = active ? this.transitionText() : ""
    wrapper.style.transform = placement.transform ?? ""
    wrapper.style.visibility = !this.dismissedAt && active && hasPayload ? "visible" : "hidden"
    for (const [name, value] of Object.entries(this.wrapperStyleValue)) wrapper.style.setProperty(name, value)
  }

  // `transform <duration>ms <easing>` only while active; with `is_animation_active: :auto` not under reduced motion
  // (`TooltipBoundingBox.js:9-17`).
  transitionText() {
    if (this.transitionAutoValue && window.matchMedia(REDUCED_MOTION).matches) return ""

    return this.transitionValue
  }

  announce(name, index, template = null) {
    if (!this.announcing) return

    const detail = template
      ? { index, label: template.dataset.label, payload: this.json(template.dataset.payload) ?? [] }
      : { index, label: null, payload: [] }
    this.dispatch(name, { detail })
  }

  // --- re-layout ("Resize and re-measure") -------------------------------------------------------------------------------------

  relayoutUrlValueChanged() {
    if (this.cache) this.startRelayout()
  }

  startRelayout() {
    this.stopRelayout()
    if (!this.relayoutUrlValue || this.relayoutStopped) return

    this.sizeObserver = observeSettledSize(this.element, (size) => this.relayout(size), {
      onChange: (size) => { if (relayoutNeeded(size, this.dimensionValue)) this.scaleInterim() },
    })
  }

  // Stops observing, aborts the request in flight and removes the interim scaling (disconnect, Turbo cache, a new URL).
  stopRelayout() {
    this.sizeObserver?.disconnect()
    this.sizeObserver = null
    this.abortRelayout()
    this.unscale?.()
    this.unscale = null
  }

  abortRelayout() {
    this.relayoutRequest?.abort()
    this.relayoutRequest = null
  }

  // While the answer is pending the drawn chart is scaled into its box (the previous layout, never an overflow or an empty box).
  scaleInterim() {
    this.unscale ??= scaleToBox(this.element)
  }

  async relayout(size) {
    if (this.cache?.pending || document.documentElement.hasAttribute("data-turbo-preview")) return
    if (!relayoutNeeded(size, this.dimensionValue)) {
      this.abortRelayout()
      this.unscale?.()
      this.unscale = null
      return
    }

    const url = relayoutRequestUrl(this.relayoutUrlValue, { id: this.element.dataset.chart.replace(/^chart-/, ""), size, metrics: this.textMetricsValue })
    if (!url) return this.failRelayout(0)

    this.scaleInterim()
    this.abortRelayout()
    const request = new AbortController()
    this.relayoutRequest = request
    let status = 0
    try {
      const response = await fetch(url, { headers: { Accept: "text/html" }, mode: "same-origin", credentials: "same-origin", signal: request.signal })
      status = response.status
      const html = response.ok ? await response.text() : null
      if (request.signal.aborted) return
      this.relayoutRequest = null
      const chart = html === null ? null : chartInResponse(html, this.element.dataset.chart)
      if (!chart || !laidOutAt(chart, size, `data-${this.identifier}-dimension-value`)) return this.failRelayout(status)

      this.swap(chart, size)
    } catch (error) {
      if (request.signal.aborted) return
      this.relayoutRequest = null
      this.failRelayout(status)
    }
  }

  // The answer replaces the element (its controller connects on its own) with the interaction state and the focus carried over.
  swap(chart, size) {
    const fresh = document.importNode(chart, true)
    const value = (attribute, fallback) => fresh.getAttribute(`data-${this.identifier}-${attribute}-value`) ?? fallback
    SERVED_STATES.set(fresh, {
      pointerIndex: Number(value("pointer-index", -1)),
      pointerActive: value("pointer-active", "false") === "true",
      keyboardIndex: Number(value("keyboard-index", -1)),
      keyboardActive: value("keyboard-active", "false") === "true",
    })
    for (const [name, attribute] of Object.entries(CARRIED_VALUES)) fresh.setAttribute(`data-${this.identifier}-${attribute}-value`, String(this[`${name}Value`]))
    const focused = this.element.contains(document.activeElement)
    this.element.replaceWith(fresh)
    if (focused) fresh.querySelector("svg.recharts-surface")?.focus({ preventScroll: true })
    fresh.dispatchEvent(new CustomEvent(`${this.identifier}:${EVENT_RELAYOUT}`, { bubbles: true, detail: { width: size.width, height: size.height } }))
  }

  // Keeps the current chart (scaled into its box) and stops re-laying out this element until it reconnects: no request loop.
  failRelayout(status) {
    this.relayoutStopped = true
    this.sizeObserver?.disconnect()
    this.sizeObserver = null
    this.dispatch(EVENT_RELAYOUT_ERROR, { detail: { status } })
  }

  // --- Turbo cache -------------------------------------------------------------------------------------------------------------

  // The snapshot holds the server state: no pointer or keyboard interaction, so the wrapper, the cursor and the dots are the
  // `default_index` ones or none. Returns the live state for `applyState` to put back. A second `turbo:before-cache` inside the window
  // carries the first one's saved live state, because the DOM is already in its snapshot shape (`primitives/turbo_cache.js`).
  resetToServerState(cancelled = { pending: false }) {
    this.stopRelayout()
    const live = cancelled.pending
      ? cancelled.state
      : { ...this.interactionState(), pointerCoordinate: this.pointerCoordinate, dismissedAt: this.dismissedAt }
    this.applyState({ ...this.serverState, pointerCoordinate: null, dismissedAt: null })
    return live
  }

  // Teardown and restore both go through here, silently: the swap puts a state back, it is not an interaction to announce.
  applyState(state) {
    this.writeInteraction(state)
    this.pointerCoordinate = state.pointerCoordinate ?? null
    this.dismissedAt = state.dismissedAt ?? null
    this.announcing = false
    try {
      this.render()
    } finally {
      this.announcing = true
    }
  }

  writeInteraction(state) {
    this.pointerIndexValue = state.pointerIndex
    this.pointerActiveValue = state.pointerActive
    this.keyboardIndexValue = state.keyboardIndex
    this.keyboardActiveValue = state.keyboardActive
  }
}
