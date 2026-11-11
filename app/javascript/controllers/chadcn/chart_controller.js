import { Controller } from "@hotwired/stimulus"
import { activeDotElements, cursorElement } from "chadcn/primitives/chart_shapes"
import { nearestTickIndex, pointerInPlot, relativePointer } from "chadcn/primitives/chart_pointer"
import { measureTextMetrics, remeasureNeeded } from "chadcn/primitives/chart_measure"
import { chartInResponse, laidOutAt, observeSettledSize, relayoutNeeded, relayoutRequestUrl, scaleToBox } from "chadcn/primitives/chart_relayout"
import { SIDE_CLASSES, tooltipPlacement } from "chadcn/primitives/chart_tooltip_placement"
import { mountTemplate } from "chadcn/primitives/template_mount"
import { turboCacheRestore } from "chadcn/primitives/turbo_cache"

// recharts' tooltip interaction (Tooltip + Cursor + ActivePoints + the accessibility layer) on a server-rendered chart. Spec:
// dev/port/specs/chart.md ("Tooltip", "Behavior"). Nothing is drawn here: the server ships one inert <template> per tooltip index and
// this controller mounts the one for the active index into `.recharts-tooltip-wrapper`, draws the cursor and the active dots from the
// template's JSON and positions the wrapper with recharts' own algorithm.
//
// An item tooltip (`Tooltip shared: false` on a BarChart or a RadialBarChart) follows the shape under the pointer instead of the category:
// the server tags every bar or arc as a `tooltipItem` with its series and position, and writes one template per series and category
// (`context/tooltipContext.js`: the hovered shape's index, series and `tooltipPosition`). A pie is an item tooltip too, but its sectors are
// not tagged, so the controller leaves it alone.
//
// Three interactions are independent states (`state/selectors/combiners/combineTooltipInteractionState.js:22-58`): the pointer's, the
// keyboard's and `default_index`. The tooltip shows the pointer index while the pointer is active, else the keyboard index while the
// keyboard is active, else `default_index` only while the pointer has never activated an index. The states are the values
// (pointerIndex/pointerActive/keyboardIndex/keyboardActive); only the pointer's last coordinate and the Escape dismissal are kept
// outside them, and both are handed over a Turbo cache round trip.
//
// With a `relayoutUrl` the chart follows the size of its element ("Behavior", "Resize and re-measure"): once the box has settled at
// another size than the server drew, or once the fonts are ready its tick text and legend box measure otherwise than the metrics the
// server assumed (`textMetrics`), the controller requests the chart from that same-origin URL at the measured size and metrics, swaps
// the answer in and hands it the interaction state. This is the recorded exception to stimulus R1 and R6 (.ai/skills/stimulus/SKILL.md):
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
const CARRIED_VALUES = {
  pointerIndex: "pointer-index", pointerActive: "pointer-active", pointerSeries: "pointer-series", keyboardIndex: "keyboard-index", keyboardActive: "keyboard-active",
}

export default class extends Controller {
  static targets = ["surface", "tooltip", "tooltipTemplate", "tooltipItem", "cursor", "activeDots"]

  static values = {
    layout: { type: String, default: "horizontal" },
    keyboardStep: { type: Number, default: 1 },
    accessibilityLayer: { type: Boolean, default: true },
    ticks: { type: Array, default: [] },
    plot: { type: Object, default: {} },
    pointerIndex: { type: Number, default: -1 },
    pointerActive: { type: Boolean, default: false },
    pointerSeries: { type: Number, default: -1 }, // the series of the item the pointer activated (item tooltips); -1 = none yet
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
    servedState: Object, // written by `swap`; no default: `connect` tells a swapped-in chart by `hasServedStateValue`
    measuredAt: Object, // written by `swap` on every answer: the size its metrics were measured at; such a chart never asks again for its metrics at that size, a resize still requests
  }

  connect() {
    this.shownKey = null
    this.shownIndex = -1
    this.announcing = true
    this.mounted = null
    this.pointerCoordinate = null
    this.dismissedAt = null
    this.activeCoordinate = null
    this.serverState = this.hasServedStateValue ? this.servedStateValue : this.interactionState()
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
    if (this.itemTooltip) return this.hoverItem(event)

    this.activateFromPointer(event, { leaveOutside: event.pointerType !== "touch" })
  }

  // `click`: the click interaction of recharts (`state/mouseEventsMiddleware.js:10-23`), the one a `trigger: click` tooltip follows
  // (`chooseAppropriateMouseInteraction`, `combineTooltipInteractionState.js:7-18`).
  click(event) {
    if (!this.listening || this.triggerValue !== "click") return
    if (this.itemTooltip) {
      const item = this.itemAt(event)
      return item ? this.activateItem(item) : undefined
    }

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
    return this.hasTooltipTarget && (this.tooltipEventTypeValue === "axis" || this.itemTooltip)
  }

  // An item tooltip whose shapes the server tagged (a BarChart or a RadialBarChart with `shared: false`; not a pie).
  get itemTooltip() {
    return this.tooltipEventTypeValue === "item" && this.hasTooltipItemTarget
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
      pointerSeries: this.pointerSeriesValue,
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

  // --- item tooltips ----------------------------------------------------------------------------------------------------------

  // A pointer moving onto a tagged shape is recharts' `mouseenter` of that shape (`setActiveMouseOverItemIndex`), off every shape its
  // `mouseleave` (`mouseLeaveItem`: the item is no longer active, its index and series are kept). A finger finds no item: recharts
  // resolves a touch through `data-recharts-item-index`, which only a Pie writes (`state/touchEventsMiddleware.js:62-71`).
  hoverItem(event) {
    if (event.pointerType === "touch") return

    const item = this.itemAt(event)
    if (item) return this.activateItem(item)
    if (!this.pointerActiveValue) return

    this.pointerActiveValue = false
    this.render()
  }

  itemAt(event) {
    return this.tooltipItemTargets.find((item) => item.contains(event.target)) ?? null
  }

  itemData(item, name) {
    return Number(item.getAttribute(`data-${this.identifier}-${name}`))
  }

  // The item's index, series and coordinate: the shape's `tooltipPosition` (a bar's center), else, for a radial bar arc that has none,
  // the `default_index` anchor (`selectActiveCoordinate` falls back to it), else none (the wrapper is not translated).
  activateItem(item) {
    const index = this.itemData(item, "index")
    const series = this.itemData(item, "series")
    if (this.pointerActiveValue && this.pointerIndexValue === index && this.pointerSeriesValue === series) return

    this.pointerCoordinate = this.itemCoordinate(index, series)
    this.pointerIndexValue = index
    this.pointerSeriesValue = series
    this.pointerActiveValue = true
    this.keyboardActiveValue = false
    this.render()
  }

  itemCoordinate(index, series) {
    const template = this.templateFor(index, series)
    const fallback = this.templateFor(this.defaultIndexValue, 0)
    return this.json(template?.dataset.itemCoordinate) ?? this.json(fallback?.dataset.coordinate)
  }

  // Where a pointer activation anchors: its own coordinate; one that is not known (a chart swapped in by a re-layout carries the indexes,
  // not the coordinate) is the item's own (an item tooltip) or the template's anchor (an axis tooltip, `undefined`).
  pointerAnchor(index, series) {
    if (this.pointerCoordinate) return this.pointerCoordinate
    return this.itemTooltip ? this.itemCoordinate(index, series) : undefined
  }

  // The series an item tooltip shows outside a pointer activation (keyboard, `active: true`, `default_index`): the one the pointer last
  // activated, else the first when `default_index` is set, else none, which shows nothing (`combineTooltipPayloadConfigurations.js:22-48`).
  get restingSeries() {
    if (this.pointerSeriesValue >= 0) return this.pointerSeriesValue
    return this.defaultIndexValue >= 0 ? 0 : -1
  }

  // Which index the tooltip shows and where it anchors (`combineTooltipInteractionState` + `selectActiveCoordinate`,
  // `state/selectors/selectors.js:49` for `selectActiveCoordinate`). `tooltipActive` false never shows, true keeps the last pointer index after the pointer left
  // (`Tooltip.js:129`, `combineTooltipInteractionState.js:39-45`).
  // An item tooltip also says which series (`series`, -1 for an axis tooltip). A `coordinate` of `undefined` means the template's anchor
  // (keyboard, `default_index`); a pointer activation keeps its own, which is `null` for a radial bar arc without a `default_index`.
  resolve() {
    const series = this.itemTooltip ? this.restingSeries : -1
    if (this.tooltipActiveValue === "false") return { index: -1, series, coordinate: null }
    if (this.pointerActiveValue) return { index: this.pointerIndexValue, series, coordinate: this.pointerAnchor(this.pointerIndexValue, series) }
    if (this.keyboardActiveValue) return { index: this.keyboardIndexValue, series, coordinate: undefined }
    if (this.pointerIndexValue >= 0) {
      const index = this.tooltipActiveValue === "true" ? this.pointerIndexValue : -1
      return { index, series, coordinate: this.pointerAnchor(this.pointerIndexValue, series) }
    }
    return { index: this.defaultIndexValue, series, coordinate: undefined }
  }

  // The template of an index (an axis tooltip) or of an index and a series (an item tooltip; -1 = no series, so none).
  templateFor(index, series = -1) {
    if (index < 0) return null
    if (this.itemTooltip && series < 0) return null

    return this.tooltipTemplateTargets.find((template) => Number(template.dataset.index) === index &&
      (!this.itemTooltip || Number(template.dataset.series) === series)) ?? null
  }

  // --- rendering ---------------------------------------------------------------------------------------------------------------

  render() {
    if (!this.interactive) return

    const resolved = this.resolve()
    const template = this.templateFor(resolved.index, resolved.series)
    const index = template ? resolved.index : -1
    const anchor = template ? this.json(template.dataset.coordinate) : null
    this.activeCoordinate = resolved.coordinate === undefined ? anchor : resolved.coordinate

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

  // Swaps the content, the cursor and the active dots when the template changes (an index, or an index and a series). The first
  // render adopts what the server drew for `default_index` (the first series of an item tooltip) instead of mounting it again.
  show(index, template) {
    const first = this.shownKey === null
    const key = template ? `${template.dataset.series ?? ""}:${index}` : ""
    if (key === this.shownKey) return

    const previous = this.shownIndex
    this.shownKey = key
    this.shownIndex = index
    const servedDefault = index === this.defaultIndexValue && (template?.dataset.series ?? "0") === "0"
    if (first && servedDefault && this.tooltipTarget.childElementCount > 0) return

    this.clearContent()
    if (!template) return previous >= 0 ? this.announce(EVENT_DEACTIVATE, previous) : undefined

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
      ? { index, label: template.dataset.label ?? null, payload: this.json(template.dataset.payload) ?? [] }
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
    this.relayoutCall = null
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

  // A settled size: once the fonts are ready, measure the text like recharts and request the chart when the size or the metrics differ
  // from what the server drew. A later settle, or stopRelayout, supersedes a call still waiting for the fonts.
  async relayout(size) {
    if (this.cache?.pending || document.documentElement.hasAttribute("data-turbo-preview")) return
    const call = {}
    this.relayoutCall = call
    await document.fonts?.ready
    if (this.relayoutCall !== call || this.relayoutStopped) return

    const metrics = measureTextMetrics(this.element, this.textMetricsValue)
    const resized = relayoutNeeded(size, this.dimensionValue)
    const measuredAt = this.hasMeasuredAtValue ? this.measuredAtValue : undefined
    const remeasured = !resized && remeasureNeeded({ measured: metrics, served: this.textMetricsValue, size, measuredAt })
    if (!resized && !remeasured) {
      this.abortRelayout()
      this.unscale?.()
      this.unscale = null
      return
    }

    const chartName = this.element.dataset.chart
    if (!chartName) return this.failRelayout(0)

    const url = relayoutRequestUrl(this.relayoutUrlValue, { id: chartName.replace(/^chart-/, ""), size, metrics })
    if (!url) return this.failRelayout(0)

    this.scaleInterim()
    this.abortRelayout()
    const request = new AbortController()
    this.relayoutRequest = request
    let status = 0
    let chart = null
    try {
      const response = await fetch(url, { headers: { Accept: "text/html" }, mode: "same-origin", credentials: "same-origin", signal: request.signal })
      status = response.status
      const html = response.ok ? await response.text() : null
      chart = html === null ? null : chartInResponse(html, chartName)
    } catch {
      if (request.signal.aborted) return
      this.relayoutRequest = null
      return this.failRelayout(status)
    }
    if (request.signal.aborted) return
    this.relayoutRequest = null
    if (!chart || !laidOutAt(chart, size, `data-${this.identifier}-dimension-value`)) return this.failRelayout(status)

    this.swap(chart, size)
  }

  // The answer replaces the element (its controller connects on its own) with the interaction state and the focus carried over. The
  // fresh element keeps the state its answer was rendered with as `servedState`, for its own Turbo snapshot, and the size as `measuredAt`:
  // every request carries the metrics measured after the fonts loaded, so every answer was laid out with browser metrics at that size.
  swap(chart, size) {
    const fresh = document.importNode(chart, true)
    const value = (attribute, fallback) => fresh.getAttribute(`data-${this.identifier}-${attribute}-value`) ?? fallback
    const served = {
      pointerIndex: Number(value("pointer-index", -1)),
      pointerActive: value("pointer-active", "false") === "true",
      pointerSeries: Number(value("pointer-series", -1)),
      keyboardIndex: Number(value("keyboard-index", -1)),
      keyboardActive: value("keyboard-active", "false") === "true",
    }
    fresh.setAttribute(`data-${this.identifier}-served-state-value`, JSON.stringify(served))
    fresh.setAttribute(`data-${this.identifier}-measured-at-value`, JSON.stringify(size))
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
    this.pointerSeriesValue = state.pointerSeries ?? -1
    this.keyboardIndexValue = state.keyboardIndex
    this.keyboardActiveValue = state.keyboardActive
  }
}
