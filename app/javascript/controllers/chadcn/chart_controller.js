import { Controller } from "@hotwired/stimulus"
import { activeDotElements, cursorElement } from "chadcn/primitives/chart_shapes"
import { nearestTickIndex, pointerInPlot, relativePointer } from "chadcn/primitives/chart_pointer"
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
const ARROWS = { ArrowRight: 1, ArrowLeft: -1 }
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)"
const EVENT_ACTIVATE = "activate"
const EVENT_DEACTIVATE = "deactivate"
// The z-index layer of the active dots: DefaultZIndexes.activeDot (recharts es6/zIndex/DefaultZIndexes.js:68).
const ACTIVE_DOT_LAYER = 1200

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
  }

  connect() {
    this.shownIndex = null
    this.announcing = true
    this.mounted = null
    this.pointerCoordinate = null
    this.dismissedAt = null
    this.activeCoordinate = null
    this.serverState = this.interactionState()
    this.cache = turboCacheRestore({
      teardown: (cancelled) => this.resetToServerState(cancelled),
      restore: (live) => this.applyState(live),
    })
    this.render()
  }

  disconnect() {
    this.cache?.release()
    this.cache = null
    // A re-inserted element starts from the server state: no interaction values, no content, a hidden wrapper.
    this.writeInteraction(this.serverState)
    this.clearContent()
    if (this.hasTooltipTarget) this.tooltipTarget.style.visibility = "hidden"
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

  // --- Turbo cache -------------------------------------------------------------------------------------------------------------

  // The snapshot holds the server state: no pointer or keyboard interaction, so the wrapper, the cursor and the dots are the
  // `default_index` ones or none. Returns the live state for `applyState` to put back. A second `turbo:before-cache` inside the window
  // carries the first one's saved live state, because the DOM is already in its snapshot shape (`primitives/turbo_cache.js`).
  resetToServerState(cancelled = { pending: false }) {
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
