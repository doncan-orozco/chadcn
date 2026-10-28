import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "chadcn/primitives/template_mount"

// shadcn InputOTP: a hand-written equivalent of input-otp 1.5.0 (no third-party JavaScript). Spec: dev/port/specs/input-otp.md
// (Behavior); the `otp:<n>` citations point at the minified input-otp source the spec cites. The server renders the container,
// the slots and the transparent input; the controller keeps the library's state (value, focused, selection) and rewrites each
// slot's character, `data-active` and fake caret from it, like OTPInputContext does for React.
//
// Events (prefix chadcn--input-otp:, detail { value }): `change` (every accepted change) and `complete` (the value reached
// max-length). A paste transformer is assigned from JavaScript: `controller.pasteTransformer = (text) => string`.
// Known divergences: none in the compared DOM; callbacks are events (spec Deviations 5).

const BADGE_SPACE = 40 // otp:28 `nt`
const BADGE_PROBE_OFFSET = 18 // otp:28 `Ot`
const BADGE_SELECTORS = ["[data-lastpass-icon-root]", "com-1password-button", "[data-dashlanecreated]", '[style$="2147483647 !important;"]'].join(",")
const BADGE_STRATEGIES = ["increase-width", "experimental-no-flickering"]
// The slot's position. Named like a Stimulus value only because the parity runner ignores that shape (spec Deviation 6); the
// controller reads it itself and declares no such value.
const SLOT_INDEX = "data-chadcn--input-otp-index-value"
const STYLE_ID = "input-otp-style"
const AUTOFILL = "background: transparent !important; color: transparent !important; border-color: transparent !important; opacity: 0 !important; box-shadow: none !important; -webkit-box-shadow: none !important; -webkit-text-fill-color: transparent !important;"
const RULES = [
  "[data-input-otp]::selection { background: transparent !important; color: transparent !important; }",
  `[data-input-otp]:autofill { ${AUTOFILL} }`,
  `[data-input-otp]:-webkit-autofill { ${AUTOFILL} }`,
  "@supports (-webkit-touch-callout: none) { [data-input-otp] { letter-spacing: -.6em !important; font-weight: 100 !important; font-stretch: ultra-condensed; font-optical-sizing: none !important; left: -1px !important; right: 1px !important; } }",
  "[data-input-otp] + * { pointer-events: all !important; }",
]

export default class extends Controller {
  static values = {
    maxLength: Number,
    pattern: String,
    controlled: Boolean,
    pushPasswordManagerStrategy: { type: String, default: "increase-width" },
    nonce: String,
  }
  static targets = ["input", "slot", "caret"]

  connect() {
    if (!this.hasInputTarget) return
    this.input = this.inputTarget
    this.isIOS = typeof CSS !== "undefined" && CSS.supports("-webkit-touch-callout", "none")
    this.value = this.input.getAttribute("value") ?? ""
    this.focused = false
    this.selectionStart = null // `mss` (otp:121 `H`)
    this.selectionEnd = null // `mse` (otp:121 `A`)
    this.committed = undefined // the value of the previous render (otp:22 usePrevious)
    this.prior = undefined
    this.syncKey = null
    this.syncTimers = []
    this.badge = { hasBadge: false, hasSpace: false, done: false, timers: [], watching: false }
    this.slots = this.slotTargets.map((element) => this.registerSlot(element))
    this.abort = new AbortController()
    const { signal } = this.abort
    const input = this.input

    input.addEventListener("input", (event) => this.typed(event), { signal })
    input.addEventListener("paste", (event) => this.pasted(event), { signal })
    input.addEventListener("focus", () => this.focusedIn(), { signal })
    input.addEventListener("blur", () => this.change(() => { this.focused = false }), { signal })
    document.addEventListener("selectionchange", () => this.normalizeSelection(), { capture: true, signal })

    // otp:78: a value the browser restored differs from the rendered one and is reported like a change.
    this.previousSelection = [input.selectionStart, input.selectionEnd, input.selectionDirection]
    if (input.value !== this.value) this.change(() => this.commit(input.value))
    // React assigns the value as a property, which leaves the caret at its end; the server-rendered attribute leaves it at 0.
    if (document.activeElement !== input && input.selectionStart === 0 && input.selectionEnd === 0) input.setSelectionRange(this.value.length, this.value.length)
    this.normalizeSelection()
    if (document.activeElement === input) this.focused = true
    this.injectStyleSheet()
    this.measureHeight()
    if (typeof ResizeObserver !== "undefined") {
      this.resize = new ResizeObserver(() => this.measureHeight())
      this.resize.observe(input)
    }
    this.watchPasswordManager()
    this.render()
  }

  get maxLength() {
    return this.maxLengthValue
  }

  get strategy() {
    return this.pushPasswordManagerStrategyValue
  }

  // The compiled `pattern` value, rebuilt only when its source changes.
  get pattern() {
    if (!this.patternValue) return null
    if (this.compiledSource !== this.patternValue) {
      this.compiledSource = this.patternValue
      this.compiledPattern = new RegExp(this.patternValue)
    }
    return this.compiledPattern
  }

  maxLengthValueChanged() {
    if (this.abort) this.render()
  }

  pushPasswordManagerStrategyValueChanged() {
    if (!this.abort) return

    this.stopBadgeWatch()
    this.watchPasswordManager()
    this.applyInputWidth()
  }

  // Slots added or removed after connect (before it, connect() registers the initial ones).
  slotTargetConnected(element) {
    if (!this.abort || this.slots.some((slot) => slot.element === element)) return

    const slot = this.registerSlot(element)
    this.slots.push(slot)
    this.renderSlot(slot)
  }

  slotTargetDisconnected(element) {
    if (!this.abort) return

    const slot = this.slots.find((candidate) => candidate.element === element)
    if (!slot) return

    this.unmountCaret(slot)
    this.slots = this.slots.filter((candidate) => candidate !== slot)
  }

  disconnect() {
    if (!this.abort) return
    this.abort.abort()
    this.resize?.disconnect()
    this.syncTimers.forEach(clearTimeout)
    this.stopBadgeWatch()
    this.slots.forEach((slot) => this.unmountCaret(slot))
    this.abort = null
  }

  // --- slots ---------------------------------------------------------------------------------------------------------

  // A cached snapshot may carry a mounted caret: only the inert template is the server markup (spec Turbo).
  registerSlot(element) {
    const template = this.caretTargets.find((caret) => caret.parentElement === element) ?? null
    while (template?.nextSibling) template.nextSibling.remove()
    return { element, template, index: Number(element.getAttribute(SLOT_INDEX)), mount: null }
  }

  unmountCaret(slot) {
    slot.mount?.unmount()
    slot.mount = null
  }

  renderSlot(slot) {
    if (slot.index < 0 || slot.index >= this.maxLength) return // the context has no slot there (otp:178): no character, no data-active

    const character = this.value[slot.index] ?? null
    const active = this.focused && this.selectionStart !== null && this.selectionEnd !== null &&
      ((this.selectionStart === this.selectionEnd && slot.index === this.selectionStart) ||
        (slot.index >= this.selectionStart && slot.index < this.selectionEnd))
    slot.element.setAttribute("data-active", String(active))
    this.renderChar(slot, character)
    const caret = active && character === null
    if (caret && !slot.mount) slot.mount = mountTemplate(slot.template, { into: "after" })
    else if (!caret) this.unmountCaret(slot)
  }

  renderChar(slot, character) {
    const node = [...slot.element.childNodes].find((child) => child.nodeType === Node.TEXT_NODE)
    if (character === null) node?.remove()
    else if (node) node.data = character
    else slot.element.prepend(document.createTextNode(character))
  }

  // --- state ---------------------------------------------------------------------------------------------------------

  // Runs `mutate` and re-renders once when the state changed (React batches the updates of an event and bails out of equal ones).
  // A nested call only mutates: the outermost one renders.
  change(mutate) {
    if (this.batching) return mutate()

    const before = [this.value, this.focused, this.selectionStart, this.selectionEnd]
    this.batching = true
    try {
      mutate()
    } finally {
      this.batching = false
    }
    if ([this.value, this.focused, this.selectionStart, this.selectionEnd].some((state, i) => state !== before[i])) this.render()
  }

  // A controlled or rejected input goes back to the rendered value (React re-renders `value={l}`, otp:162).
  restoreInput() {
    if (this.input.value !== this.value) this.input.value = this.value
  }

  render() {
    this.prior = this.committed
    this.committed = this.value
    const { input } = this
    this.restoreInput()
    input.setAttribute("value", this.value)
    this.toggleData("data-input-otp-placeholder-shown", this.value.length === 0 ? "true" : null)
    this.toggleData("data-input-otp-mss", this.selectionStart)
    this.toggleData("data-input-otp-mse", this.selectionEnd)
    this.applyInputWidth()
    this.slots.forEach((slot) => this.renderSlot(slot))
    this.afterRender()
  }

  toggleData(name, value) {
    if (value === null) this.input.removeAttribute(name)
    else this.input.setAttribute(name, String(value))
  }

  // The effects of otp:122-134, run after every render.
  afterRender() {
    const key = `${this.value}|${this.focused}`
    if (key !== this.syncKey) {
      this.syncKey = key
      this.scheduleSync()
    }
    if (this.focused !== this.badge.focused) {
      this.badge.focused = this.focused
      this.scheduleBadgeChecks()
    }
    const { prior, value, maxLength } = this
    if (prior !== undefined && value !== prior && prior.length < maxLength && value.length === maxLength) this.dispatch("complete", { detail: { value }, cancelable: false })
  }

  scheduleSync() {
    this.syncTimers.forEach(clearTimeout)
    this.syncTimers = [0, 10, 50].map((ms) => setTimeout(() => this.sync(), ms))
  }

  // otp:122: re-reads the input (autofill) and the selection, even while blurred.
  sync() {
    if (!this.abort) return
    if (this.input.value !== this.value) this.accept(this.input.value)
    const { selectionStart: start, selectionEnd: end, selectionDirection: direction } = this.input
    if (start === null || end === null) return
    this.change(() => { this.selectionStart = start; this.selectionEnd = end })
    this.previousSelection = [start, end, direction]
  }

  // --- input ---------------------------------------------------------------------------------------------------------

  typed(event) {
    this.accept(this.input.value, event)
  }

  // otp:136-141
  accept(raw, event) {
    const next = raw.slice(0, this.maxLength)
    if (next.length > 0 && this.pattern && !this.pattern.test(next)) {
      event?.preventDefault()
      this.restoreInput()
      return
    }
    this.change(() => {
      if (this.prior !== undefined && next.length < this.prior.length) document.dispatchEvent(new Event("selectionchange"))
      this.commit(next)
    })
    this.restoreInput()
  }

  // otp:71 `O`: report the change; the internal state is ignored while the value is controlled.
  commit(next) {
    this.dispatch("change", { detail: { value: next }, cancelable: false })
    if (!this.controlledValue) this.value = next
  }

  // otp:142-148
  focusedIn() {
    const length = this.input.value.length
    const start = Math.min(length, this.maxLength - 1)
    this.input.setSelectionRange(start, length)
    this.change(() => {
      this.selectionStart = start
      this.selectionEnd = length
      this.focused = true
    })
  }

  // otp:149-160: only intercepted on iOS or with a pasteTransformer; elsewhere the browser pastes natively.
  pasted(event) {
    const clipboard = event.clipboardData
    if (!clipboard || (!this.pasteTransformer && !this.isIOS)) return

    const text = clipboard.getData("text/plain")
    const pasted = this.pasteTransformer ? this.pasteTransformer(text) : text
    event.preventDefault()
    const { selectionStart: start, selectionEnd: end } = this.input
    const joined = start !== end ? this.value.slice(0, start) + pasted + this.value.slice(end) : this.value.slice(0, start) + pasted + this.value.slice(start)
    const next = joined.slice(0, this.maxLength)
    if (next.length > 0 && this.pattern && !this.pattern.test(next)) return

    this.input.value = next
    const from = Math.min(next.length, this.maxLength - 1)
    this.change(() => {
      this.commit(next)
      this.input.setSelectionRange(from, next.length)
      this.selectionStart = from
      this.selectionEnd = next.length
    })
    this.restoreInput()
  }

  // --- selection (otp:78-105, verbatim) ------------------------------------------------------------------------------

  normalizeSelection() {
    const input = this.input
    if (document.activeElement !== input) {
      this.change(() => { this.selectionStart = null; this.selectionEnd = null })
      return
    }
    const start = input.selectionStart
    const end = input.selectionEnd
    const direction = input.selectionDirection
    const max = input.maxLength
    const value = input.value
    const previousSelection = this.previousSelection
    let from = -1
    let to = -1
    let dir
    if (value.length !== 0 && start !== null && end !== null) {
      const collapsed = start === end
      const atPartialEnd = start === value.length && value.length < max
      if (collapsed && !atPartialEnd) {
        if (start === 0) {
          from = 0
          to = 1
          dir = "forward"
        } else if (start === max) {
          from = start - 1
          to = start
          dir = "backward"
        } else if (max > 1 && value.length > 1) {
          let offset = 0
          if (previousSelection[0] !== null && previousSelection[1] !== null) {
            dir = start < previousSelection[1] ? "backward" : "forward"
            const wasCaretBeforeEnd = previousSelection[0] === previousSelection[1] && previousSelection[0] < max
            if (dir === "backward" && !wasCaretBeforeEnd) offset = -1
          }
          from = offset + start
          to = offset + start + 1
        }
      }
      if (from !== -1 && to !== -1 && from !== to) input.setSelectionRange(from, to, dir)
    }
    const nextStart = from !== -1 ? from : start
    const nextEnd = to !== -1 ? to : end
    this.change(() => { this.selectionStart = nextStart; this.selectionEnd = nextEnd })
    this.previousSelection = [nextStart, nextEnd, dir ?? direction]
  }

  // --- layout --------------------------------------------------------------------------------------------------------

  measureHeight() {
    this.element.style.setProperty("--root-height", `${this.input.clientHeight}px`)
  }

  // otp:105-111: the library's global sheet, once per document and never removed.
  injectStyleSheet() {
    if (document.getElementById(STYLE_ID)) return

    const style = document.createElement("style")
    style.id = STYLE_ID
    if (this.nonceValue) style.setAttribute("nonce", this.nonceValue)
    document.head.appendChild(style)
    if (!style.sheet) return
    RULES.forEach((rule) => {
      try {
        style.sheet.insertRule(rule)
      } catch {
        console.warn("input-otp could not insert CSS rule:", rule)
      }
    })
  }

  // --- password manager badge (otp:29-67) ----------------------------------------------------------------------------

  get pushesBadge() {
    return BADGE_STRATEGIES.includes(this.strategy) && this.badge.hasBadge && this.badge.hasSpace
  }

  applyInputWidth() {
    const push = this.pushesBadge
    this.input.style.width = push ? `calc(100% + ${BADGE_SPACE}px)` : "100%"
    this.input.style.clipPath = push ? `inset(0px ${BADGE_SPACE}px 0px 0px)` : ""
  }

  spaceRight() {
    const right = this.element.getBoundingClientRect().right
    for (let node = this.element; node; node = node.parentElement) {
      if (getComputedStyle(node).overflowX !== "visible") return node.getBoundingClientRect().left + node.clientLeft + node.clientWidth - right
    }
    return document.documentElement.clientWidth - right
  }

  watchPasswordManager() {
    if (this.strategy === "none") return

    const measure = () => this.setBadge({ hasSpace: this.spaceRight() >= BADGE_SPACE })
    measure()
    this.badge.interval = setInterval(measure, 1000)
  }

  stopBadgeWatch() {
    clearInterval(this.badge.interval)
    this.badge.timers.forEach(clearTimeout)
  }

  scheduleBadgeChecks() {
    this.badge.timers.forEach(clearTimeout)
    this.badge.timers = []
    if (this.strategy === "none" || !(this.focused || document.activeElement === this.input)) return

    this.badge.timers = [
      setTimeout(() => this.checkBadge(), 0),
      setTimeout(() => this.checkBadge(), 2000),
      setTimeout(() => this.checkBadge(), 5000),
      setTimeout(() => { this.badge.done = true }, 6000),
    ]
  }

  checkBadge() {
    if (!this.abort || this.badge.done || this.strategy === "none") return

    const box = this.element.getBoundingClientRect()
    const x = box.left + this.element.offsetWidth - BADGE_PROBE_OFFSET
    const y = box.top + this.element.offsetHeight / 2
    if (document.querySelectorAll(BADGE_SELECTORS).length === 0 && document.elementFromPoint(x, y) === this.element) return

    this.setBadge({ hasSpace: this.spaceRight() >= BADGE_SPACE, hasBadge: true, done: true })
  }

  setBadge(next) {
    const before = this.pushesBadge
    Object.assign(this.badge, next)
    if (before !== this.pushesBadge) this.applyInputWidth()
  }
}
