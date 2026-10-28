import { Controller } from "@hotwired/stimulus"

// @shadcn/react 0.3.1 message-scroller, re-implemented (spec: dev/port/specs/message-scroller.md, Behavior; `ms:<line>` cites the
// pretty-printed library). Host = the Provider div. The content's element children other than the spacer are the rows.
//
// Modes: "following-bottom" (pinned to the live edge), "free-scrolling", "settling-jump" (after scrollToMessage) and
// "anchored-to-message" (a new turn sits at the top, the spacer makes that reachable).
const SUBPIXEL = 0.5 // `J`, ms:5
const AUTOSCROLLING_MS = 180 // `je`, ms:5
const SCROLL_KEYS = new Set(["ArrowDown", "ArrowUp", "End", "Home", "PageDown", "PageUp", " "]) // `Ge`
const NO_VISIBILITY = { currentAnchorId: null, visibleMessageIds: [] }
const NOTHING_SCROLLABLE = { start: false, end: false }

export default class extends Controller {
  static targets = ["root", "viewport", "content", "spacer", "button"]
  static values = {
    autoScroll: Boolean,
    defaultScrollPosition: { type: String, default: "end" },
    scrollEdgeThreshold: { type: Number, default: 8 },
    scrollPreviousItemPeek: { type: Number, default: 64 },
    scrollMargin: { type: Number, default: 0 },
    trackVisibility: Boolean
  }

  connect() {
    this.viewport = this.hasViewportTarget ? this.viewportTarget : null
    this.content = this.hasContentTarget ? this.contentTarget : null
    this.spacer = this.hasSpacerTarget ? this.spacerTarget : null
    this.mode = this.autoScrollValue ? "following-bottom" : "free-scrolling"
    this.state = NOTHING_SCROLLABLE
    this.visibility = NO_VISIBILITY
    this.autoscrolling = false
    this.defaultApplied = false
    this.pinOpeningEnd = false
    this.itemCount = 0
    this.firstRow = null
    this.lastScrollTop = 0
    this.spacerHeight = 0
    this.spacerGap = this.#rowGap(this.spacer?.parentElement)
    this.pendingJump = null
    this.prependRestore = null
    this.anchoredTurn = null
    this.handledAnchors = new WeakSet()
    this.observedRows = new Set()
    this.visibleIds = new Set()
    this.frames = { commit: null, visibility: null, viewportResize: null, contentResize: null }
    this.autoscrollTimer = null
    this.connected = true

    this.#resetSpacerMarkup()
    this.#writeAttributes(this.state)
    this.buttonTargets.forEach((button) => this.#updateButton(button))
    this.#observeLayout()
    this.#contentChanged() // the content layout effect (ms:405-411)
    if (!this.defaultApplied && this.itemCount === 0) this.#clearPending() // ms:321-322
    this.#syncAutoScroll() // ms:325-331
    if (this.trackVisibilityValue) this.#observeVisibility()
  }

  disconnect() {
    this.connected = false
    for (const name of Object.keys(this.frames)) this.#cancelFrame(name)
    window.clearTimeout(this.autoscrollTimer)
    this.autoscrollTimer = null
    this.mutationObserver?.disconnect()
    this.viewportResizeObserver?.disconnect()
    this.contentResizeObserver?.disconnect()
    this.mutationObserver = this.viewportResizeObserver = this.contentResizeObserver = null
    this.#unobserveVisibility()
  }

  autoScrollValueChanged() {
    if (this.connected) this.#syncAutoScroll()
  }

  defaultScrollPositionValueChanged() {
    if (!this.connected) return
    this.defaultApplied = false
    this.#applyDefaultPosition()
  }

  trackVisibilityValueChanged() {
    if (!this.connected) return
    this.trackVisibilityValue ? this.#observeVisibility() : this.#unobserveVisibility()
  }

  buttonTargetConnected(button) {
    if (this.connected) this.#updateButton(button)
  }

  // ---- Commands (actions or direct calls; each returns whether it ran, like the React hooks) ----

  scrollToStart(options) { // ms:162
    if (!this.viewport) return false
    this.pinOpeningEnd = false
    this.#setSpacer(0)
    this.anchoredTurn = null
    this.mode = "free-scrolling"
    this.#scrollTo(0, { behavior: this.#behaviorOf(options) })
    this.#scheduleVisibilitySync()
    return true
  }

  scrollToEnd(options) {
    this.pinOpeningEnd = false
    return this.#scrollToEnd(options)
  }

  #scrollToEnd(options) { // ms:163-164
    if (!this.viewport) return false
    this.#setSpacer(0)
    this.anchoredTurn = null
    this.mode = this.autoScrollValue ? "following-bottom" : "free-scrolling"
    this.#scrollTo(Math.max(0, this.viewport.scrollHeight - this.viewport.clientHeight), { behavior: this.#behaviorOf(options), autoscrolling: true })
    this.#scheduleVisibilitySync()
    return true
  }

  // scrollToMessage(id, { align, behavior, scrollMargin }) or the action with params messageId, align, behavior, scrollMargin. ms:173-176
  scrollToMessage(target, options = {}) {
    const params = target?.params
    const id = params ? params.messageId : target
    const { align = "start", behavior = "auto", scrollMargin = this.scrollMarginValue } = params || options
    const jump = { messageId: String(id), options: { align, behavior, scrollMargin } }
    const row = this.#rows().find((candidate) => candidate.dataset.messageId === jump.messageId)
    if (row) {
      this.#markDefaultApplied()
      this.pendingJump = this.#scrollToElement(row, jump.options) ? null : jump
      return true
    }
    if (this.itemCount !== 0) return false
    this.pendingJump = jump
    this.#markDefaultApplied()
    return true
  }

  // The button's click (ms:434-436): the caller's handlers ran first.
  press(event) {
    const button = event.currentTarget
    if (button.dataset.active !== "true" || event.defaultPrevented) return
    button.blur()
    const options = { behavior: event.params.behavior }
    button.dataset.direction === "start" ? this.scrollToStart(options) : this.scrollToEnd(options)
  }

  // ---- Viewport input ----

  syncAfterScroll() { // ms:318-320
    this.#commit()
    this.#scheduleVisibilitySync()
    this.#rememberVisibleRow()
  }

  userScrollIntent() { // ms:312-314
    this.pinOpeningEnd = false
    if (this.mode === "free-scrolling") return
    this.anchoredTurn = null
    this.mode = "free-scrolling"
  }

  userScrollKey(event) {
    if (SCROLL_KEYS.has(event.key)) this.userScrollIntent()
  }

  // ---- Wiring ----

  #observeLayout() {
    if (this.content && typeof MutationObserver !== "undefined") {
      this.mutationObserver = new MutationObserver(() => this.#contentChanged())
      this.mutationObserver.observe(this.content, { childList: true })
    }
    if (typeof ResizeObserver === "undefined") return
    this.viewportResizeObserver = this.#resizeObserver(this.viewport, "viewportResize")
    this.contentResizeObserver = this.#resizeObserver(this.content, "contentResize")
  }

  #resizeObserver(element, frame) {
    if (!element) return null
    const observer = new ResizeObserver(() => {
      window.cancelAnimationFrame(this.frames[frame])
      this.frames[frame] = window.requestAnimationFrame(() => {
        this.frames[frame] = null
        this.#resized()
      })
    })
    observer.observe(element)
    return observer
  }

  #cancelFrame(name) {
    if (this.frames[name] !== null) window.cancelAnimationFrame(this.frames[name])
    this.frames[name] = null
  }

  #syncAutoScroll() {
    if (this.autoScrollValue && this.mode === "following-bottom" && this.itemCount > 0) this.#scrollToEnd({ behavior: "auto" })
    else this.#commit()
  }

  // ---- Published state ----

  #measure() { // `Ne`, ms:6-10
    if (!this.viewport || !this.content) return NOTHING_SCROLLABLE
    const bottom = this.#contentBottom()
    const threshold = this.scrollEdgeThresholdValue
    return { start: this.viewport.scrollTop > threshold, end: bottom - this.viewport.scrollTop - this.viewport.clientHeight > threshold }
  }

  #commit() { // `N`, ms:198-203
    const measured = this.#measure()
    this.#updateMode(measured)
    const published = this.mode === "following-bottom" ? { ...measured, end: false } : measured
    this.#writeAttributes(published)
    this.#publish(published)
  }

  #updateMode(measured) { // `be`, ms:195-197
    const scrollTop = this.viewport?.scrollTop ?? 0
    const scrolledUp = scrollTop < this.lastScrollTop - SUBPIXEL
    this.lastScrollTop = scrollTop
    if (this.autoScrollValue && !measured.end && this.mode !== "settling-jump" && this.mode !== "anchored-to-message") this.mode = "following-bottom"
    else if (this.mode === "following-bottom" && measured.end && scrolledUp && !this.autoscrolling) this.mode = "free-scrolling"
  }

  #scheduleCommit() { // `oe`, ms:203-207
    if (this.frames.commit !== null) return
    this.frames.commit = window.requestAnimationFrame(() => {
      this.frames.commit = null
      this.#commit()
    })
  }

  #writeAttributes(state) { // `ce`, ms:192-194
    const value = [state.start && "start", state.end && "end"].filter(Boolean).join(" ")
    for (const element of [this.hasRootTarget && this.rootTarget, this.viewport]) {
      if (!element) continue
      value ? element.setAttribute("data-scrollable", value) : element.removeAttribute("data-scrollable")
      element.toggleAttribute("data-autoscrolling", this.autoscrolling)
    }
  }

  #publish(state) {
    if (state.start === this.state.start && state.end === this.state.end) return
    this.state = state
    this.buttonTargets.forEach((button) => this.#updateButton(button))
    this.dispatch("scrollable-change", { detail: { start: state.start, end: state.end }, cancelable: false })
  }

  #updateButton(button) { // ms:431-434, 437
    const active = button.dataset.direction === "start" ? this.state.start : this.state.end
    button.dataset.active = active ? "true" : "false"
    button.toggleAttribute("inert", !active)
    const activeTabindex = button.getAttribute("data-chadcn--message-scroller-active-tabindex")
    if (!active) button.setAttribute("tabindex", "-1")
    else if (activeTabindex === null) button.removeAttribute("tabindex")
    else button.setAttribute("tabindex", activeTabindex)
  }

  #setAutoscrolling(on) { // `Y`, ms:144-147
    window.clearTimeout(this.autoscrollTimer)
    this.autoscrollTimer = null
    if (this.autoscrolling !== on) {
      this.autoscrolling = on
      this.#commit()
    }
    if (!on) return
    this.autoscrollTimer = window.setTimeout(() => {
      this.autoscrollTimer = null
      this.#finishAutoscrolling()
    }, AUTOSCROLLING_MS)
  }

  // `data-autoscrolling` hides the scrollbar, so ending it can grow the content (text wraps again). React opens at the end from
  // an estimated height (rows it never rendered count 10rem), which the browser clamps to the final end once the rows lay out;
  // the rows of a server-rendered page already have their size, so the opening position is pinned to the end when the flag ends.
  // Later commands behave as in React (they keep what the scroll reached).
  #finishAutoscrolling() {
    const viewport = this.viewport
    const wasAtEnd = viewport && this.pinOpeningEnd && this.#distanceToEnd() <= this.scrollEdgeThresholdValue
    this.autoscrolling = false
    this.#writeAttributes(this.state)
    if (wasAtEnd && this.#distanceToEnd() > this.scrollEdgeThresholdValue) viewport.scrollTop = viewport.scrollHeight - viewport.clientHeight
    this.#commit()
  }

  #distanceToEnd() {
    return this.viewport.scrollHeight - this.viewport.clientHeight - this.viewport.scrollTop
  }

  #clearPending() { // `Me`, ms:137-139
    for (const element of [this.hasRootTarget && this.rootTarget, this.viewport]) element?.removeAttribute("data-pending-scroll")
  }

  #markDefaultApplied() { // `re`
    this.defaultApplied = true
    this.#clearPending()
  }

  // ---- Scrolling ----

  #behaviorOf(options) {
    return (options?.params ? options.params.behavior : options?.behavior) ?? "auto"
  }

  #scrollTo(top, { behavior = "auto", autoscrolling = false } = {}) { // `V`, ms:153-161
    const clamped = Math.max(0, top)
    if (Math.abs(this.viewport.scrollTop - clamped) <= SUBPIXEL) {
      this.viewport.scrollTop = clamped
      this.#commit()
      return
    }
    if (autoscrolling) this.#setAutoscrolling(true)
    this.viewport.scrollTo({ top: clamped, behavior })
    this.#scheduleCommit()
  }

  // `x`, ms:148-152: the spacer makes the scroll target reachable; its negative margin cancels the row gap above it.
  #setSpacer(height) {
    if (!this.spacer) return
    const rounded = Math.max(0, Math.ceil(height))
    if (this.spacerHeight === rounded) return
    this.spacerHeight = rounded
    this.spacer.hidden = rounded === 0
    this.spacer.style.height = `${rounded}px`
    this.spacer.style.marginTop = rounded > 0 ? `${-this.spacerGap}px` : ""
  }

  // The server markup is the zero state; a Turbo snapshot may carry the previous run's spacer size.
  #resetSpacerMarkup() {
    if (!this.spacer) return
    this.spacer.hidden = true
    this.spacer.style.height = ""
    this.spacer.style.marginTop = ""
  }

  #scrollToElement(element, { align = "start", behavior = "auto", scrollMargin = this.scrollMarginValue } = {}, { keepPreviousPeek = false } = {}) { // ms:165-169
    if (!this.content || !this.viewport || !this.content.contains(element)) return false
    this.pinOpeningEnd = false
    const margin = keepPreviousPeek ? scrollMargin + this.scrollPreviousItemPeekValue : scrollMargin
    const target = this.#targetTop(element, align, margin)
    this.#setSpacer(target + this.viewport.clientHeight - this.#contentBottom()) // `Je`
    this.prependRestore = { element, viewportTop: this.#offsetInViewport(element) }
    this.mode = keepPreviousPeek ? "anchored-to-message" : "settling-jump"
    this.anchoredTurn = keepPreviousPeek ? element : null
    this.#scrollTo(target, { behavior })
    this.#scheduleVisibilitySync()
    return true
  }

  #targetTop(element, align, margin) { // `$e`, ms:57-69
    const viewport = this.viewport
    const top = this.#scrollOrigin(element)
    const height = element.getBoundingClientRect().height
    const padding = this.#padding(this.spacer?.parentElement)
    if (align === "center") return top - padding.start - (Math.max(0, viewport.clientHeight - padding.start - padding.end) - height) / 2 - margin
    if (align === "end") return top - viewport.clientHeight + height + padding.end + margin
    if (align === "nearest") {
      const bottom = top + height
      const visibleStart = viewport.scrollTop + padding.start
      const visibleEnd = viewport.scrollTop + viewport.clientHeight - padding.end
      if (top >= visibleStart && bottom <= visibleEnd) return viewport.scrollTop
      return top < visibleStart ? top - padding.start - margin : bottom - viewport.clientHeight + padding.end + margin
    }
    return top - padding.start - margin
  }

  #reanchor() { // `le`, ms:170-172
    const turn = this.anchoredTurn
    if (!turn || !turn.isConnected || this.mode !== "anchored-to-message") return false
    return this.#scrollToElement(turn, { align: "start" }, { keepPreviousPeek: true })
  }

  // ---- Geometry ----

  #rows() { // `ee`, ms:22-24
    return this.content ? Array.from(this.content.children).filter((child) => child instanceof HTMLElement && child !== this.spacer) : []
  }

  #scrollOrigin(element) { // `me`, ms:70-73
    return element.getBoundingClientRect().top - this.viewport.getBoundingClientRect().top + this.viewport.scrollTop
  }

  #offsetInViewport(element) { // `te`, ms:74-76
    return element.getBoundingClientRect().top - this.viewport.getBoundingClientRect().top
  }

  #contentBottom() { // `Re`, ms:81-88: the spacer is not counted
    const padding = this.#padding(this.content)
    const viewportTop = this.viewport.getBoundingClientRect().top
    let bottom = padding.start + padding.end
    for (const row of this.#rows()) bottom = Math.max(bottom, row.getBoundingClientRect().bottom - viewportTop + this.viewport.scrollTop + padding.end)
    return bottom
  }

  #padding(element) { // `Xe`, `ht`
    if (!element) return { start: 0, end: 0 }
    const style = window.getComputedStyle(element)
    return { start: this.#pixels(style.paddingBlockStart || style.paddingTop), end: this.#pixels(style.paddingBlockEnd || style.paddingBottom) }
  }

  #rowGap(element) { // `Ze`, ms:100-104
    if (!element) return 0
    const style = window.getComputedStyle(element)
    return this.#pixels(style.rowGap === "normal" ? style.gap : style.rowGap)
  }

  #pixels(value) {
    const number = Number.parseFloat(value)
    return Number.isFinite(number) ? number : 0
  }

  // ---- Content changes ----

  // `Le`, ms:240-275: once on connect and on every childList mutation of the content.
  #contentChanged() {
    if (!this.content || !this.viewport) return
    const rows = this.#rows()
    const previousCount = this.itemCount
    const previousFirst = this.firstRow
    this.itemCount = rows.length
    this.firstRow = rows[0] ?? null
    this.#syncObservedRows(rows)
    this.#reactToRows(rows, previousCount, previousFirst)
    this.#rememberVisibleRow()
  }

  #reactToRows(rows, previousCount, previousFirst) {
    if (this.#flushPendingJump()) return
    if (previousCount === 0) {
      if (this.#applyDefaultPosition() || (rows.length > 0 && this.autoScrollValue && this.#scrollToEnd({ behavior: "auto" }))) return
      this.#commit()
      this.#scheduleVisibilitySync()
      return
    }
    const previousIndex = previousFirst ? rows.indexOf(previousFirst) : -1
    if (this.#preservesPrepend() && previousIndex > 0) {
      this.#restorePrepend()
      return
    }
    if (rows.length > previousCount) {
      const anchor = rows.slice(previousCount).find((row) => row.dataset.scrollAnchor === "true")
      if (anchor) {
        if (this.autoScrollValue && this.mode === "following-bottom" && this.#severalAnchors(rows, previousCount)) this.#scrollToEnd({ behavior: "auto" })
        else this.#anchorTurn(anchor)
        return
      }
    }
    if (rows.length === previousCount) {
      const anchor = rows.find((row) => row.dataset.scrollAnchor === "true" && !this.handledAnchors.has(row))
      if (anchor) {
        this.#anchorTurn(anchor)
        return
      }
    }
    if (this.mode === "following-bottom" && this.autoScrollValue) {
      this.#scrollToEnd({ behavior: "auto" })
      return
    }
    this.#commit()
    this.#scheduleVisibilitySync()
  }

  #anchorTurn(row) {
    this.#scrollToElement(row, { align: "start" }, { keepPreviousPeek: true })
    this.handledAnchors.add(row)
  }

  #severalAnchors(rows, from) { // `qe`, ms:36-40
    return rows.slice(from).filter((row) => row.dataset.scrollAnchor === "true").length > 1
  }

  #preservesPrepend() {
    return this.viewport.getAttribute("data-chadcn--message-scroller-preserve-scroll-on-prepend") !== "false"
  }

  #flushPendingJump() { // ms:177-181
    const jump = this.pendingJump
    if (!jump) return false
    const row = this.#rows().find((candidate) => candidate.dataset.messageId === jump.messageId)
    if (!row || !this.#scrollToElement(row, jump.options)) return false
    this.pendingJump = null
    this.#markDefaultApplied()
    return true
  }

  // `ue`, ms:228-240: the opening position, once per value and only with rows.
  #applyDefaultPosition() {
    const position = this.defaultScrollPositionValue
    if (!position || this.defaultApplied || this.itemCount === 0) return false
    let applied
    if (position === "last-anchor") applied = this.#openAtLastAnchor()
    else applied = position === "end" ? this.#scrollToEnd({ behavior: "auto" }) : this.scrollToStart({ behavior: "auto" })
    if (!applied) return false
    this.pinOpeningEnd = this.mode !== "anchored-to-message" && position !== "start"
    this.#markDefaultApplied()
    return true
  }

  #openAtLastAnchor() {
    const anchor = this.#rows().findLast((row) => row.dataset.scrollAnchor === "true")
    if (!anchor || !this.viewport) return this.#scrollToEnd({ behavior: "auto" })
    const fits = this.#contentBottom() - this.#scrollOrigin(anchor) <= this.viewport.clientHeight
    return fits ? this.#scrollToEnd({ behavior: "auto" }) : this.#scrollToElement(anchor, { align: "start" }, { keepPreviousPeek: true })
  }

  // ---- Prepend preservation ----

  #restorePrepend() { // `ve`, ms:211-216
    const remembered = this.prependRestore
    if (!remembered || !remembered.element.isConnected) return false
    const shift = this.#offsetInViewport(remembered.element) - remembered.viewportTop
    if (Math.abs(shift) <= SUBPIXEL) return false
    this.viewport.scrollTop += shift
    remembered.viewportTop = this.#offsetInViewport(remembered.element)
    this.#scheduleCommit()
    this.#scheduleVisibilitySync()
    return true
  }

  #rememberVisibleRow() { // `Z` and `We`, ms:48-56, 216-224
    if (!this.content || !this.viewport) {
      this.prependRestore = null
      return
    }
    const bounds = this.viewport.getBoundingClientRect()
    const row = this.#rows().find((candidate) => {
      if (!candidate.dataset.messageId) return false
      const rect = candidate.getBoundingClientRect()
      return rect.bottom > bounds.top && rect.top < bounds.bottom
    })
    this.prependRestore = row ? { element: row, viewportTop: this.#offsetInViewport(row) } : null
  }

  #resized() { // `Ce`, ms:276-287
    if (this.mode === "following-bottom" && this.autoScrollValue) {
      this.#scrollToEnd({ behavior: "auto" })
      return
    }
    const spacerBefore = this.spacerHeight
    if (this.#reanchor()) {
      if (this.autoScrollValue && spacerBefore > 0 && this.spacerHeight === 0) this.#scrollToEnd({ behavior: "auto" })
      return
    }
    this.#scheduleCommit()
    this.#scheduleVisibilitySync()
  }

  // ---- Visibility (track_visibility) ----

  #observeVisibility() { // `Pe`, ms:288-303
    if (!this.viewport) return
    if (typeof IntersectionObserver === "undefined") {
      this.#scheduleVisibilitySync()
      return
    }
    this.intersectionObserver ??= new IntersectionObserver((entries) => {
      for (const entry of entries) {
        const id = entry.target.dataset.messageId
        if (!id) continue
        entry.isIntersecting ? this.visibleIds.add(id) : this.visibleIds.delete(id)
      }
      this.#scheduleVisibilitySync()
    }, {
      root: this.viewport,
      rootMargin: `${-(this.scrollMarginValue + this.scrollPreviousItemPeekValue)}px 0px 0px 0px`,
      threshold: [0, 0.01, 0.5, 1]
    })
    this.#syncObservedRows(this.#rows())
    this.#scheduleVisibilitySync()
  }

  #unobserveVisibility() { // `we`, ms:304-305
    this.#cancelFrame("visibility")
    this.intersectionObserver?.disconnect()
    this.intersectionObserver = null
    this.observedRows.clear()
    this.visibleIds.clear()
    this.#setVisibility(NO_VISIBILITY)
  }

  // Rows register and unregister with the content (React: the Item ref callback, ms:306-311).
  #syncObservedRows(rows) {
    if (!this.intersectionObserver) return
    const current = new Set(rows.filter((row) => row.dataset.messageId))
    for (const row of this.observedRows) {
      if (current.has(row)) continue
      this.intersectionObserver.unobserve(row)
      this.observedRows.delete(row)
      this.visibleIds.delete(row.dataset.messageId)
    }
    for (const row of current) {
      if (this.observedRows.has(row)) continue
      this.intersectionObserver.observe(row)
      this.observedRows.add(row)
    }
  }

  #scheduleVisibilitySync() {
    if (!this.trackVisibilityValue || this.frames.visibility !== null) return
    this.frames.visibility = window.requestAnimationFrame(() => {
      this.frames.visibility = null
      if (this.trackVisibilityValue) this.#setVisibility(this.#measureVisibility())
    })
  }

  #measureVisibility() { // `Ue`, ms:11-21
    if (!this.content || !this.viewport) return NO_VISIBILITY
    const bounds = this.viewport.getBoundingClientRect()
    const anchorLine = bounds.top + this.scrollMarginValue + this.scrollPreviousItemPeekValue
    const withoutObserver = typeof IntersectionObserver === "undefined"
    const visibleMessageIds = []
    let currentAnchorId = null
    for (const row of this.#rows()) {
      const id = row.dataset.messageId
      if (!id) continue
      const anchor = row.dataset.scrollAnchor === "true"
      const rect = anchor || withoutObserver ? row.getBoundingClientRect() : null
      if (withoutObserver && rect ? rect.bottom > anchorLine && rect.top < bounds.bottom : this.visibleIds.has(id)) visibleMessageIds.push(id)
      if (anchor && rect && rect.top <= anchorLine + SUBPIXEL) currentAnchorId = id
    }
    return visibleMessageIds.length === 0 && currentAnchorId === null ? NO_VISIBILITY : { currentAnchorId, visibleMessageIds }
  }

  #setVisibility(next) { // store equality `Lt`, ms:130
    const previous = this.visibility
    const same = previous.currentAnchorId === next.currentAnchorId && previous.visibleMessageIds.length === next.visibleMessageIds.length &&
      previous.visibleMessageIds.every((id, index) => id === next.visibleMessageIds[index])
    if (same) return
    this.visibility = next
    this.dispatch("visibility-change", { detail: { currentAnchorId: next.currentAnchorId, visibleMessageIds: [...next.visibleMessageIds] }, cancelable: false })
  }
}
