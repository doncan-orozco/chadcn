import { Controller } from "@hotwired/stimulus"
import { anchorPositioner } from "shadcn/primitives/anchor_positioner"
import { dismissable } from "shadcn/primitives/dismissable_layer"
import { hideOthers } from "shadcn/primitives/hide_others"
import { generateId } from "shadcn/primitives/ids"
import { presence } from "shadcn/primitives/presence"
import { rank } from "shadcn/primitives/scorer"
import { scrollLock } from "shadcn/primitives/scroll_lock"
import { mountTemplate } from "shadcn/primitives/template_mount"
import { typeahead } from "shadcn/primitives/typeahead"

// shadcn Combobox: a hand-written equivalent of Base UI 1.9.0 `Combobox` (no third-party JavaScript). Spec:
// dev/port/specs/combobox.md (Behavior); the `root:` / `input:` / `nav:` citations of the comments point at the Base UI sources the spec cites.
// The server renders the host, the parts that are always in the document (input, trigger, chips, clear, hidden inputs) and the popup
// in an inert <template>; the controller mounts that template into `body > div[data-base-ui-portal]` while open, filters the list by
// detaching/re-attaching its item nodes, and keeps the Base UI state machine (open, highlight, query, selection) in this object.
//
// State of the host (Stimulus values, written back so a Turbo snapshot restores it): `selected` (form values of the selection),
// `open`, `inputValue`. `config` is static. With `value:` / `open:` / `input_value:` given the matching value is CONTROLLED: the events fire
// and the DOM waits for the caller to change the attribute.
//
// Events (prefix shadcn--combobox:, bubbling; cancelable ones map Base UI's `eventDetails.cancel()` to preventDefault()):
// `value-change` { value, reason } (value = the item's form value), `open-change` { open, reason }, `input-value-change`
// { inputValue, reason }, `item-highlighted` { value, index, reason } and `open-change-complete` { open } (not cancelable).
//
// Known divergences: item identity on the client is the form value (equality callables run on the server, see Combobox::Model); the
// modal popup traps no focus (the input keeps it; Tab leaves and closes, like the non-modal popup); `value-change` carries the form value, not the
// item object; the closed-trigger typeahead and the autofill match use the form value / label of the item.

const PART = "data-shadcn--combobox-part"
const KEY = "data-shadcn--combobox-key"
const part = (name) => `[${PART}="${name}"]`
const VISUALLY_HIDDEN_INPUT = "clip-path: inset(50%); overflow: hidden; white-space: nowrap; border: 0px; padding: 0px; width: 1px; height: 1px; margin: -1px; position: absolute;"
const VISUALLY_HIDDEN_FIXED = "clip-path: inset(50%); overflow: hidden; white-space: nowrap; border: 0px; padding: 0px; width: 1px; height: 1px; margin: 0px; position: fixed; top: 0px; left: 0px;"
const LIVE_MARKER = "⁠"
const LIVE_RESET_MS = 200
const TYPEAHEAD_RESET_MS = 750
const INTERACTIVE = "button,a[href],[role=\"button\"],select,[tabindex]:not([tabindex=\"-1\"]),input,textarea"

export default class extends Controller {
  static values = { config: Object, selected: Array, open: Boolean, inputValue: String }

  connect() {
    this.cfg = this.configValue
    this.template = this.element.querySelector(part("content-template"))
    this.abort = new AbortController()
    const { signal } = this.abort
    this.labels = new Map([...this.cfg.items, ...(this.cfg.extras ?? [])].map(({ k, l }) => [k, l]))
    this.selected = [...this.selectedValue]
    this.control = this.element.querySelector(part("input"))
    this.inPopup = !this.control
    // A search field inside the popup starts empty (Base UI clears it when it mounts) unless the caller gave its text.
    this.text = this.inPopup && !this.cfg.inputValueGiven ? "" : this.inputValueValue
    this.initialText = this.text
    this.isOpen = false
    this.queryEdited = false
    this.closeQuery = null
    this.active = -1
    this.pointerModality = true
    this.hadInputClear = false
    this.mountedPopup = null
    this.options = JSON.parse(this.template?.getAttribute("data-shadcn--combobox-options") ?? "{}")
    this.collator = new Intl.Collator(this.cfg.locale ?? undefined, { usage: "search", sensitivity: "base", ignorePunctuation: true })

    this.hidden = this.element.querySelector(part("hidden-input"))
    this.chipKeys = new WeakMap()
    this.chipElements().forEach((chip, index) => this.chipKeys.set(chip, this.selected[index]))
    this.listen(this.element, signal)
    this.hidden?.addEventListener("focus", () => (this.field ?? this.trigger)?.focus(), { signal })
    this.hidden?.addEventListener("change", (event) => this.autofill(event), { signal })
    document.addEventListener("turbo:before-cache", () => this.reset(), { signal })

    this.syncControls()
    this.ready = true
    if (this.openValue && !this.cfg.disabled) this.applyOpen(true, "none", null, { focus: false })
  }

  disconnect() {
    this.ready = false
    if (!this.abort) return
    this.unmountPopup({ immediate: true })
    this.abort.abort()
    this.typeaheadBuffer?.release()
    this.typeaheadBuffer?.reset()
    this.typeaheadBuffer = null
    this.abort = null
  }

  // --- Stimulus values: controlled changes -----------------------------------------------------------------------------

  openValueChanged(value) {
    if (!this.ready || value === this.isOpen) return
    if (this.cfg.disabled && value) return
    this.applyOpen(value, "none", null, { focus: false })
  }

  selectedValueChanged(value) {
    if (!this.ready) return
    const next = [...value]
    if (next.join("\u0000") === this.selected.join("\u0000")) return
    this.selected = next
    this.renderSelection()
  }

  inputValueValueChanged(value) {
    if (!this.ready || value === this.text) return
    this.applyText(value)
  }

  // --- wiring -------------------------------------------------------------------------------------------------------------

  // The same handlers serve the host (input, trigger, chips) and the mounted popup (items, search field), routed by event target.
  listen(root, signal) {
    const on = (type, handler, options = {}) => root.addEventListener(type, handler, { signal, ...options })
    on("keydown", (event) => this.keydown(event))
    on("input", (event) => this.typed(event))
    on("mousedown", (event) => this.mousedown(event))
    on("click", (event) => this.clicked(event))
    on("focusout", (event) => this.focusedOut(event))
    on("pointerdown", (event) => this.pointerdown(event), { capture: true })
    on("pointermove", () => { this.pointerModality = true })
    on("mousemove", (event) => this.mousemove(event))
    on("pointerout", (event) => this.pointerout(event))
    on("mouseup", (event) => this.mouseup(event))
    on("compositionend", (event) => this.typed(event))
  }

  get single() {
    return !this.cfg.multiple
  }

  get field() {
    return this.inPopup ? this.mountedPopup?.input : this.control
  }

  get trigger() {
    return this.element.querySelector(part("trigger"))
  }

  get chips() {
    return this.element.querySelector(part("chips"))
  }

  label(key) {
    return this.labels.get(key) ?? key
  }

  selectedLabel() {
    return this.single && this.selected.length ? this.label(this.selected[0]) : ""
  }

  emit(name, detail, { cancelable = true } = {}) {
    return this.dispatch(name, { detail, cancelable })
  }

  // --- query, filter (root:L225-330) -------------------------------------------------------------------------------------

  // The text that filters; while the popup closes it stays what it was (`closeQuery`) so the list does not jump during the exit.
  query() {
    return !this.isOpen && this.closeQuery !== null ? this.closeQuery : this.text.trim()
  }

  filterQuery() {
    const query = this.query()
    const label = this.selectedLabel()
    const bypass = this.single && !this.queryEdited && query !== "" && label.length === query.length && this.contains(label, query)
    return bypass ? "" : query
  }

  // Base UI default filter (filter:L9-33): Intl.Collator substring match.
  contains(text, query) {
    if (!query) return true
    for (let i = 0; i <= text.length - query.length; i += 1) {
      if (this.collator.compare(text.slice(i, i + query.length), query) === 0) return true
    }
    return false
  }

  // The list items that match (null: no `items:`, the static children are all shown and nothing is filtered). The fuzzy filter returns
  // them best match first and applies `limit` AFTER ranking; the other filters keep source order. Memoized per query: several callers
  // ask for it on every keystroke. `scores` maps form value to fuzzy score (null for the other filters).
  matches() {
    return this.matchResult()?.list ?? null
  }

  matchResult() {
    if (!this.cfg.hasItems) return null
    const query = this.filterQuery()
    if (this.matchCache?.query === query) return this.matchCache
    const { filter, limit } = this.cfg
    let list = this.cfg.items
    let scores = null
    if (query !== "" && filter === "fuzzy") {
      const ranked = rank(query, list, { text: (item) => item.l })
      list = ranked.map(({ item }) => item)
      scores = new Map(ranked.map(({ item, score }) => [item.k, score]))
    } else if (query !== "" && filter !== null) {
      list = list.filter((item) => this.contains(item.l, query))
    }
    this.matchCache = { query, list: limit > -1 ? list.slice(0, limit) : list, scores }
    return this.matchCache
  }

  get listEmpty() {
    const matches = this.matches()
    return matches === null || matches.length === 0
  }

  // --- selection --------------------------------------------------------------------------------------------------------

  // Asks to change the selection; false when the caller cancelled. Controlled: the event fires, the selection stays.
  setSelected(next, reason) {
    const value = this.single ? (next[0] ?? null) : next
    if (this.emit("value-change", { value, reason }).defaultPrevented) return false
    if (!this.cfg.valueControlled) {
      this.selected = [...next]
      this.selectedValue = [...next]
      this.renderSelection()
    }
    if (this.single && !this.inPopup) this.setText(this.single && next.length ? this.label(next[0]) : "", reason)
    return true
  }

  renderSelection() {
    this.syncHiddenInputs()
    this.renderValues()
    this.syncControls()
    this.syncClear()
    if (this.selected.length) this.chips?.setAttribute("role", "toolbar")
    else this.chips?.removeAttribute("role")
    if (this.mountedPopup) this.renderItemStates()
  }

  syncHiddenInputs() {
    const value = this.single ? (this.selected[0] ?? "") : ""
    this.writeValue(this.hidden, value)
    if (this.hidden) this.hidden.required = this.cfg.required && !(this.cfg.multiple && this.selected.length)
    if (this.single || !this.cfg.name) return
    // React keys these inputs by value: the ones that stay keep their node.
    const current = new Map([...this.element.querySelectorAll(part("form-value"))].map((input) => [input.value, input]))
    const inputs = this.selected.map((key) => current.get(key) ?? this.formValueInput(key))
    current.forEach((input, key) => { if (!this.selected.includes(key)) input.remove() })
    this.hidden.after(...inputs)
  }

  formValueInput(key) {
    const input = document.createElement("input")
    input.type = "hidden"
    if (this.cfg.form) input.setAttribute("form", this.cfg.form)
    input.name = this.cfg.name
    input.value = key
    input.disabled = this.cfg.disabled
    input.setAttribute(PART, "form-value")
    return input
  }

  // The hidden input keeps what a native form submits; like React it also tells listeners when the value changed.
  writeValue(input, value) {
    if (!input || input.value === value) return
    input.value = value
    input.setAttribute("value", value)
    this.writingHidden = true
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
    this.writingHidden = false
  }

  // Native autofill writes the label or value of an option into the hidden input (root:L1231-1281).
  autofill(event) {
    if (this.writingHidden || event.defaultPrevented || this.cfg.disabled || this.cfg.readOnly || !this.single) return
    const wanted = this.hidden.value.toLowerCase()
    const item = this.cfg.items.find(({ k, l }) => k.toLowerCase() === wanted || l.toLowerCase() === wanted)
    if (item) queueMicrotask(() => this.setSelected([item.k], "none"))
  }

  // Value parts: the content between the `value-start` / `value-end` markers follows the selection.
  renderValues() {
    this.element.querySelectorAll(part("value-start")).forEach((start) => this.renderValue(start))
  }

  renderValue(start) {
    const end = this.markerEnd(start)
    if (!end) return
    const prototypes = new Map([...start.content.querySelectorAll(part("value-prototype"))].map((proto) => [proto.getAttribute("data-key"), proto]))
    const live = []
    for (let node = start.nextSibling; node && node !== end; node = node.nextSibling) live.push(node)
    if (!prototypes.size) return this.renderValueText(start, end, live)
    if (this.single) {
      const proto = prototypes.get(this.selected[0] ?? "")
      live.forEach((node) => node.remove())
      if (proto) end.before(proto.content.cloneNode(true))
      return
    }
    this.renderChips(prototypes, live, end)
  }

  // React keys the chips by position and value: the leading chips that did not change keep their node, the rest are rebuilt.
  renderChips(prototypes, live, end) {
    const isChip = (node) => node.nodeType === Node.ELEMENT_NODE && node.matches("[data-slot=combobox-chip]")
    const current = live.filter(isChip)
    const others = live.filter((node) => !isChip(node))
    let stable = 0
    while (stable < current.length && this.chipKeys.get(current[stable]) === this.selected[stable]) stable += 1
    current.slice(stable).forEach((chip) => chip.remove())
    const rebuilt = this.selected.slice(stable).flatMap((key) => {
      const proto = prototypes.get(key)
      const chips = proto ? [...proto.content.cloneNode(true).querySelectorAll("[data-slot=combobox-chip]")] : []
      chips.forEach((chip) => this.chipKeys.set(chip, key))
      return chips
    })
    ;(others[0] ?? end).before(...rebuilt)
  }

  renderValueText(start, end, live) {
    const placeholder = start.getAttribute("data-has-placeholder") === "true" ? start.getAttribute("data-placeholder") : null
    const text = !this.selected.length && placeholder !== null ? placeholder : this.selected.map((key) => this.label(key)).join(", ")
    live.forEach((node) => node.remove())
    if (text !== "") end.before(document.createTextNode(text))
  }

  markerEnd(start) {
    for (let node = start.nextSibling; node; node = node.nextSibling) {
      if (node.nodeType === Node.ELEMENT_NODE && node.matches(part("value-end"))) return node
    }
    return null
  }

  // Clear button: mounted while something is selected, unmounted after its exit (clear:L47-124).
  syncClear() {
    const template = this.element.querySelector(part("clear-template"))
    if (!template) return
    const live = this.element.querySelector(part("clear"))
    const visible = this.selected.length > 0
    if (visible && !live) {
      const fragment = template.content.cloneNode(true)
      const button = fragment.firstElementChild
      button.setAttribute("data-visible", "")
      if (this.isOpen) button.setAttribute("data-popup-open", "")
      template.after(fragment)
    } else if (visible && live) {
      live.removeAttribute("data-ending-style")
      live.setAttribute("data-visible", "")
      this.clearExit = null
    } else if (!visible && live && !live.hasAttribute("data-ending-style")) {
      live.removeAttribute("data-visible")
      live.setAttribute("data-ending-style", "")
      const token = (this.clearExit = Symbol("clear"))
      requestAnimationFrame(async () => {
        await Promise.all(live.getAnimations().map((animation) => animation.finished.catch(() => {})))
        if (this.clearExit === token) live.remove()
      })
    }
    this.element.querySelector(part("clear"))?.toggleAttribute("data-popup-open", this.isOpen)
  }

  // --- text of the input (root:L350-420) ---------------------------------------------------------------------------------

  setText(next, reason) {
    if (this.emit("input-value-change", { inputValue: next, reason }).defaultPrevented) return false
    this.hadInputClear = reason === "input-clear"
    if (this.cfg.inputValueControlled) {
      this.writeField(this.text)
      return true
    }
    this.applyText(next)
    return true
  }

  applyText(next) {
    this.text = next
    if (!this.cfg.inputValueControlled) this.inputValueValue = next
    this.writeField(next)
    if (this.isOpen && this.text.trim() !== "" && this.text.trim() !== this.initialText && !(this.single && !this.inPopup && this.text === this.selectedLabel())) {
      this.queryEdited = true
    }
    this.afterQueryChange()
  }

  writeField(value) {
    for (const input of [this.control, this.mountedPopup?.input]) {
      if (!input) continue
      if (input.value !== value) input.value = value
      input.setAttribute("value", value)
    }
  }

  // The input fires `input` for typing and for IME commits; autofill-like input does not open the popup (input:L195-257).
  typed(event) {
    const input = event.target
    if (!input.matches?.(part("input"))) return
    if (event.isComposing) return
    if (this.cfg.disabled) return
    const value = input.value
    const typed = event.type === "compositionend" || (event.inputType != null && event.inputType !== "" && event.inputType !== "insertReplacementText")
    this.cancelCloseQuery()
    if (!this.setText(value, "input-change")) return input.value = this.text
    if (typed && value.trim() !== "") {
      this.queryEdited = true
      this.pendingQueryHighlight = true
      this.afterQueryChange()
      this.resetListScroll()
    }
    if (value === "" && !this.inPopup) {
      if (this.single) this.setSelected([], "input-clear")
      if (!this.cfg.openOnInputClick) this.requestOpen(false, "input-clear", event)
    }
    if (!this.cfg.readOnly && !this.cfg.disabled && value.trim() !== "" && typed) {
      this.requestOpen(true, "input-change", event)
      if (!this.cfg.autoHighlight) this.setActive(-1, "keyboard", event)
    }
    if (this.isOpen && this.active !== -1 && !this.cfg.autoHighlight) this.setActive(-1, "keyboard", event)
    if (this.pendingQueryHighlight && this.cfg.autoHighlight && value.trim() !== "" && this.mountedPopup && this.shown.length) {
      this.setActive(0, "keyboard", event)
    }
    this.pendingQueryHighlight = false
  }

  // A controlled popup may ignore a close request; typing again proves it is staying open.
  cancelCloseQuery() {
    if (this.isOpen && this.closeQuery !== null) this.closeQuery = null
  }

  resetListScroll() {
    if (this.mountedPopup?.list) this.mountedPopup.list.scrollTop = 0
  }

  // --- open / close (root:L580-650, popup mount) ------------------------------------------------------------------------

  // `setOpen`: Base UI asks the caller first; a controlled popup keeps its state until the attribute changes.
  requestOpen(next, reason, event, { query = this.query() } = {}) {
    if (next === this.isOpen || !this.template) return
    if (next && this.cfg.disabled) return
    if (this.emit("open-change", { open: next, reason }).defaultPrevented) return
    if (next && this.closeQuery !== null) this.interruptedReopen(reason === "input-change")
    if (!next && this.queryEdited) {
      this.closeQuery = query
      if (this.single) {
        if (query === "") this.queryEdited = false
      } else {
        if (this.inPopup) this.setActive(-1, reason)
        else this.setText("", "input-clear")
      }
    }
    if (this.cfg.openControlled) return
    this.openValue = next
    this.applyOpen(next, reason, event)
  }

  // A reopen while the popup was closing keeps what the interrupted close froze.
  interruptedReopen(isInputChange) {
    const pending = !isInputChange && this.inPopup && this.text !== "" && (this.text.trim() === this.closeQuery || this.text === this.selectedLabel())
    if (!isInputChange && (pending || this.text === "" || (this.single && !this.inPopup && this.text === this.selectedLabel()))) this.queryEdited = false
    this.closeQuery = null
    if (pending) this.setText("", "input-clear")
  }

  applyOpen(next, reason, event, { focus = true } = {}) {
    if (next === this.isOpen && (!next || this.mountedPopup)) return
    this.isOpen = next
    this.keyOpened = event?.type === "keydown" ? event.key : null
    if (next) {
      this.mountedPopup ? this.reopenPopup() : this.mountPopup({ focus })
      this.openHighlight(reason)
    } else {
      this.closePopup(reason)
    }
    this.syncControls()
    this.syncClear()
    this.syncDismissStart()
  }

  // State attributes of the controls that are always in the document (the input and the trigger).
  syncControls() {
    const open = this.isOpen
    const empty = this.listEmpty
    const popupState = this.mountedPopup
    const side = popupState?.side ?? null
    for (const el of [this.control, this.trigger]) {
      if (!el) continue
      const controls = el === this.trigger && this.inPopup ? (popupState?.popup.id || `${this.cfg.id}-popup`) : (popupState?.list.id || `${this.cfg.id}-list`)
      el.setAttribute("aria-expanded", String(open))
      el.toggleAttribute("data-popup-open", open)
      el.toggleAttribute("data-pressed", open)
      el.toggleAttribute("data-list-empty", empty)
      if (side) el.setAttribute("data-popup-side", side)
      else el.removeAttribute("data-popup-side")
      if (open) el.setAttribute("aria-controls", controls)
      else el.removeAttribute("aria-controls")
      if (el === this.trigger) el.toggleAttribute("data-placeholder", this.selected.length === 0)
      else if (!open) el.removeAttribute("aria-activedescendant")
    }
    const popupInput = popupState?.input
    if (popupInput) {
      popupInput.toggleAttribute("data-list-empty", empty)
      if (side) popupInput.setAttribute("data-popup-side", side)
    }
  }

  // Dismiss button before the input while a modal focus manager is open (input outside the popup; input:L341-343).
  syncDismissStart() {
    const existing = this.element.querySelector(part("dismiss-start"))
    if (!this.isOpen || this.inPopup || !this.control) return existing?.remove()
    if (existing) return
    const span = document.createElement("span")
    span.setAttribute("role", "button")
    span.setAttribute("aria-label", "Dismiss")
    span.setAttribute("style", VISUALLY_HIDDEN_INPUT)
    span.setAttribute(PART, "dismiss-start")
    this.control.before(span)
  }

  mountPopup({ focus }) {
    const container = document.createElement("div")
    container.setAttribute("data-base-ui-portal", "")
    container.id = generateId("combobox-portal")
    document.body.append(container)
    const popupState = { container, releases: [], openReleases: [], side: null, listeners: new AbortController() }
    this.mountedPopup = popupState
    if (this.cfg.modal) popupState.backdrop = this.backdrop(container)
    popupState.mount = mountTemplate(this.template, { into: container })
    popupState.positioner = popupState.mount.nodes[0]
    popupState.popup = popupState.positioner.querySelector(part("popup"))
    popupState.list = popupState.positioner.querySelector(part("list"))
    popupState.input = popupState.positioner.querySelector(part("input"))
    popupState.empty = popupState.positioner.querySelector(part("empty"))
    popupState.emptyNodes = popupState.empty ? [...popupState.empty.childNodes] : []
    this.listen(popupState.positioner, popupState.listeners.signal)
    this.pointerModality = true
    this.collectRecords()
    this.mountState()
    this.renderList()
    this.renderItemStates()
    this.markLiveRegion()
    this.place()
    this.addDismissEnd(popupState)
    this.addFocusGuards(popupState)
    this.addOpenLayers(popupState)
    popupState.presence = presence(popupState.popup, { onExited: () => this.unmountPopup() })
    if (this.inPopup && popupState.input) {
      popupState.input.value = this.text
      popupState.input.setAttribute("value", this.text)
      // After the press has run its default action (a mouse press focuses the trigger first, then focus moves in).
      if (focus) popupState.focusFrame = requestAnimationFrame(() => popupState.input.focus({ preventScroll: true }))
    }
    this.syncControls()
  }

  backdrop(container) {
    const el = document.createElement("div")
    el.setAttribute("role", "presentation")
    el.setAttribute("data-base-ui-inert", "")
    el.setAttribute("aria-hidden", "true")
    const cutout = (this.inPopup ? this.trigger : this.control)?.getBoundingClientRect()
    const clip = cutout
      ? `polygon(0% 0%, 100% 0%, 100% 100%, 0% 100%, 0% 0%, ${cutout.left}px ${cutout.top}px, ${cutout.left}px ${cutout.bottom}px, ${cutout.right}px ${cutout.bottom}px, ${cutout.right}px ${cutout.top}px, ${cutout.left}px ${cutout.top}px)`
      : ""
    el.style.cssText = `position: fixed; inset: 0px; user-select: none; clip-path: ${clip};`
    container.append(el)
    return el
  }

  // Data attributes of the mounted positioner and popup (open/closed, side, align, empty).
  mountState() {
    const { positioner, popup } = this.mountedPopup
    const side = this.options.side ?? "bottom"
    const align = this.options.align ?? "start"
    this.mountedPopup.side = side
    for (const el of [positioner, popup]) {
      el.setAttribute("data-open", "")
      el.setAttribute("data-side", side)
      el.setAttribute("data-align", align)
    }
    popup.setAttribute("data-base-ui-focusable", "")
    // Base UI mounts with `transition: none` for one frame, so the transform origin set by the first placement does not animate.
    popup.setAttribute("data-starting-style", "")
    popup.style.transition = "none"
    this.mountedPopup.startFrame = requestAnimationFrame(() => {
      popup.removeAttribute("data-starting-style")
      popup.style.removeProperty("transition")
      if (!popup.getAttribute("style")) popup.removeAttribute("style")
    })
    this.syncEmptyState()
  }

  syncEmptyState() {
    const popupState = this.mountedPopup
    if (!popupState) return
    const empty = this.listEmpty
    for (const el of [popupState.positioner, popupState.popup, popupState.list]) el.toggleAttribute("data-empty", empty)
    const container = popupState.empty
    if (!container) return
    if (empty && !container.childNodes.length) container.append(...popupState.emptyNodes)
    else if (!empty) popupState.emptyNodes.forEach((node) => node.remove())
  }

  // The first mount with text announces itself with a word joiner for 200 ms (live:L8-58).
  markLiveRegion() {
    const container = this.mountedPopup.empty
    if (!container || !this.listEmpty) return
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT)
    let last = null
    while (walker.nextNode()) if (walker.currentNode.nodeValue !== "") last = walker.currentNode
    if (!last) return
    const original = last.data
    const marked = original + LIVE_MARKER
    last.nodeValue = marked
    const timer = setTimeout(() => { if (last.nodeValue === marked) last.nodeValue = original }, LIVE_RESET_MS)
    this.mountedPopup.releases.push(() => { clearTimeout(timer); if (last.nodeValue === marked) last.nodeValue = original })
  }

  anchor() {
    if (this.options.anchor) {
      const el = document.querySelector(this.options.anchor)
      if (el) return el
    }
    return this.inPopup ? this.trigger : this.control
  }

  place() {
    const popupState = this.mountedPopup
    const anchor = this.anchor()
    if (!anchor) return
    const dir = getComputedStyle(this.element).direction
    popupState.placement = anchorPositioner(anchor, popupState.positioner, {
      side: this.options.side,
      sideOffset: this.options.sideOffset,
      align: this.options.align,
      alignOffset: this.options.alignOffset,
      lazyFlip: true,
      dir,
      onPlace: ({ side, align, anchorHidden }) => {
        popupState.side = side
        popupState.popup.setAttribute("data-side", side)
        popupState.popup.setAttribute("data-align", align)
        popupState.popup.toggleAttribute("data-anchor-hidden", anchorHidden)
        this.syncPopupSide(side)
      }
    })
    popupState.releases.push(() => popupState.placement.release())
  }

  syncPopupSide(side) {
    for (const el of [this.control, this.trigger]) el?.setAttribute("data-popup-side", side)
  }

  // The dismiss button after the popup: a keyboard way to close it (popup:L113-115).
  addDismissEnd(popupState) {
    if (this.inPopup && !this.cfg.modal) return
    const end = document.createElement("span")
    end.setAttribute("role", "button")
    end.setAttribute("aria-label", "Dismiss")
    end.setAttribute("style", VISUALLY_HIDDEN_INPUT)
    end.setAttribute(PART, "dismiss-end")
    end.addEventListener("click", (event) => this.requestOpen(false, "close-press", event), { signal: popupState.listeners.signal })
    popupState.positioner.append(end)
  }

  // Popup with its own search field (FloatingPortal + non-modal focus manager): sentinels around the trigger and the popup. Tabbing onto
  // one of them moves focus into the popup (outside guards) or closes it and returns focus to the trigger (inside guards).
  addFocusGuards(popupState) {
    if (!this.inPopup || !this.trigger) return
    const guard = (type, handler) => {
      const span = document.createElement("span")
      span.setAttribute("data-type", type)
      span.setAttribute("aria-hidden", "true")
      span.tabIndex = 0
      span.setAttribute("data-base-ui-focus-guard", "")
      span.setAttribute("style", VISUALLY_HIDDEN_FIXED)
      span.addEventListener("focus", handler, { signal: this.abort.signal })
      return span
    }
    const enter = () => popupState.input?.focus({ preventScroll: true })
    const leave = (event) => this.requestOpen(false, "focus-out", event)
    const owns = document.createElement("span")
    owns.setAttribute("aria-owns", popupState.container.id)
    owns.setAttribute("style", "clip-path: inset(50%); position: fixed; top: 0px; left: 0px;")
    const outside = [guard("outside", enter), owns, guard("outside", enter)]
    this.trigger.after(...outside)
    popupState.releases.push(() => outside.forEach((el) => el.remove()))
    popupState.positioner.prepend(guard("inside", leave))
    popupState.positioner.append(guard("inside", leave))
  }

  // What only an open popup holds: outside-press and Escape (dismissable layer), aria-hidden/inert on the page, the scroll lock.
  // They end when the close starts, not when the exit animation does (ffm:L335-354).
  addOpenLayers(popupState) {
    const { popup, openReleases } = popupState
    openReleases.push(dismissable(popup, {
      branches: () => [this.trigger, this.element.querySelector(part("clear")), this.chips, this.control, this.hidden].filter(Boolean),
      onEscape: (event) => { this.dismiss = { reason: "escape-key", event } },
      onPointerDownOutside: (event) => { this.dismiss = { reason: "outside-press", event: event.detail.originalEvent } },
      onFocusOutside: (event) => event.preventDefault(),
      onDismiss: () => this.requestOpen(false, this.dismiss?.reason ?? "none", this.dismiss?.event ?? null)
    }))
    openReleases.push(this.hideOutside(popupState))
    if (this.cfg.modal) openReleases.push(scrollLock())
  }

  // aria-hidden on everything but the popup, the reference input and live regions (an input outside the popup, or a modal popup);
  // `data-base-ui-inert` on the outermost body children that are not the portal.
  hideOutside(popupState) {
    const ariaHidden = !this.inPopup || this.cfg.modal
    const keep = [popupState.container, this.control, this.element.querySelector(part("dismiss-start"))].filter(Boolean)
    // Base UI marks with `aria-hidden` only, not with the primitive's own `data-aria-hidden` marker.
    const release = ariaHidden ? hideOthers(keep, document.body, { marker: false }) : () => {}
    const marked = [...document.body.children].filter((child) => child !== popupState.container && child.tagName !== "SCRIPT" && !child.hasAttribute("data-base-ui-inert"))
    marked.forEach((el) => el.setAttribute("data-base-ui-inert", ""))
    return () => {
      release()
      marked.forEach((el) => el.removeAttribute("data-base-ui-inert"))
    }
  }

  reopenPopup() {
    const popupState = this.mountedPopup
    popupState.presence.enter()
    for (const el of [popupState.positioner, popupState.popup]) {
      el.removeAttribute("data-closed")
      el.setAttribute("data-open", "")
    }
    popupState.popup.removeAttribute("data-ending-style")
    popupState.positioner.style.removeProperty("pointer-events")
    this.addOpenLayers(popupState)
    this.renderList()
  }

  closePopup(reason) {
    const popupState = this.mountedPopup
    if (!popupState) return
    this.closeReason = reason
    popupState.openReleases.splice(0).reverse().forEach((release) => release())
    for (const el of [popupState.positioner, popupState.popup]) {
      el.removeAttribute("data-open")
      el.setAttribute("data-closed", "")
    }
    popupState.popup.setAttribute("data-ending-style", "")
    popupState.positioner.style.pointerEvents = "none"
    this.syncEmptyState()
    popupState.presence.exit()
  }

  // handleUnmountCleanup (root:L717-756) plus the focus the popup returns to its trigger.
  unmountPopup({ immediate = false } = {}) {
    const popupState = this.mountedPopup
    if (!popupState) return
    if (!immediate) this.setActive(-1, "none")
    this.mountedPopup = null
    popupState.listeners.abort()
    cancelAnimationFrame(popupState.startFrame)
    cancelAnimationFrame(popupState.focusFrame)
    popupState.presence?.release()
    popupState.openReleases.splice(0).reverse().forEach((release) => release())
    popupState.releases.splice(0).reverse().forEach((release) => release())
    popupState.mount.unmount()
    popupState.backdrop?.remove()
    popupState.container.remove()
    this.active = -1
    this.element.querySelectorAll(part("input")).forEach((input) => input.removeAttribute("aria-activedescendant"))
    if (immediate) {
      this.isOpen = false
      return
    }
    this.emit("open-change-complete", { open: false }, { cancelable: false })
    this.queryEdited = false
    this.closeQuery = null
    this.finishText()
    if (this.inPopup && !["focus-out", "outside-press"].includes(this.closeReason)) this.trigger?.focus({ preventScroll: true })
    this.syncControls()
  }

  finishText() {
    if (this.single) {
      if (this.inPopup) {
        if (this.text !== "") this.setText("", "input-clear")
      } else {
        const label = this.selectedLabel()
        if (this.text !== label) this.setText(label, label === "" ? "input-clear" : "none")
      }
    } else if (this.text !== "" && !this.hadInputClear) {
      this.setText("", "input-clear")
    }
  }

  // Turbo snapshot / disconnect: a cached page shows the closed server state with the current selection.
  reset() {
    if (!this.abort) return
    const wasOpen = this.isOpen
    this.unmountPopup({ immediate: true })
    this.isOpen = false
    this.queryEdited = false
    this.closeQuery = null
    this.matchCache = null
    this.clearExit = null
    const leaving = this.element.querySelector(part("clear"))
    if (leaving?.hasAttribute("data-ending-style") && this.selected.length === 0) leaving.remove()
    if (wasOpen && !this.cfg.openControlled) this.openValue = false
    if (this.single && !this.inPopup && !this.cfg.inputValueControlled) this.applyText(this.selectedLabel())
    this.syncControls()
    this.syncClear()
    this.syncDismissStart()
  }

  // --- the list inside the popup ------------------------------------------------------------------------------------------

  afterQueryChange() {
    if (this.mountedPopup) this.renderList()
    else this.syncControls()
  }

  collectRecords() {
    const { list, positioner } = this.mountedPopup
    this.records = new Map()
    this.sources = new Map()
    const groups = [...positioner.querySelectorAll(part("group"))]
    for (const container of [list, ...groups]) if (container) this.sources.set(container, [...container.children])
    for (const el of positioner.querySelectorAll(part("item"))) {
      this.records.set(el, { el, key: el.getAttribute(KEY), disabled: el.hasAttribute("data-disabled"), group: el.closest(part("group")) })
    }
    this.shown = [...this.records.keys()]
  }

  // Detaches the items that do not match and re-attaches the ones that do, ranked for the fuzzy filter (spec, Filtering).
  renderList() {
    const popupState = this.mountedPopup
    if (!popupState?.list) return
    const result = this.matchResult()
    const visible = result ? new Set(result.list.map(({ k }) => k)) : null
    const scores = result?.scores
    const present = (el) => this.records.has(el) && (visible === null || visible.has(this.records.get(el).key))
    const hasVisible = new Map()
    for (const [container, source] of this.sources) hasVisible.set(container, source.some(present))
    for (const [container, source] of this.sources) {
      let items = source.filter(present)
      if (scores) items = items.map((el, index) => ({ el, index })).sort((a, b) => scores.get(this.records.get(b.el).key) - scores.get(this.records.get(a.el).key) || a.index - b.index).map(({ el }) => el)
      let next = 0
      const children = source.flatMap((node) => {
        if (this.records.has(node)) return next < items.length ? [items[next++]] : []
        if (this.sources.has(node) && !hasVisible.get(node)) return []
        return [node]
      })
      container.replaceChildren(...children)
    }
    this.shown = [...popupState.list.querySelectorAll(part("item"))]
    this.shown.forEach((el, index) => { el.id = `${this.cfg.id}-${index}` })
    this.syncEmptyState()
    this.syncControls()
    if (this.active >= this.shown.length) this.setActive(-1, "none")
    else this.paintActive()
    if (this.cfg.autoHighlight === "always" && this.active === -1 && this.shown.length) this.setActive(0, "none")
  }

  renderItemStates() {
    const template = this.mountedPopup?.list?.querySelector(part("indicator-template"))
    for (const record of this.records.values()) {
      const selected = this.selected.includes(record.key)
      const { el } = record
      el.setAttribute("aria-selected", String(selected))
      el.toggleAttribute("data-selected", selected)
      const indicator = el.querySelector("[data-slot=combobox-item-indicator]")
      if (selected && !indicator && template) el.append(template.content.cloneNode(true))
      if (!selected) indicator?.remove()
    }
  }

  // --- highlight (nav:L303-411, root:L760-870) ------------------------------------------------------------------------------

  // The index highlighted when the popup opens: the first selected item, else (arrow key) the first/last one that is not disabled.
  openHighlight(reason) {
    if (!this.mountedPopup || this.queryEdited) return
    const selectedIndex = this.shown.findIndex((el) => this.selected.includes(this.records.get(el).key))
    if (selectedIndex >= 0) return this.setActive(selectedIndex, reason, null, { scroll: true })
    const enabled = this.shown.map((el, index) => ({ el, index })).filter(({ el }) => !this.records.get(el).disabled)
    if (this.keyOpened === "ArrowDown" && enabled.length) this.setActive(enabled[0].index, "list-navigation", null, { scroll: true })
    else if (this.keyOpened === "ArrowUp" && enabled.length) this.setActive(enabled.at(-1).index, "list-navigation", null, { scroll: true })
    else if (this.cfg.autoHighlight === "always" && this.shown.length) this.setActive(0, "none")
  }

  // Sets the highlighted index (-1: none), paints it and tells the caller. Keyboard moves scroll the item into view.
  setActive(index, reason, event = null, { scroll = false } = {}) {
    const next = this.mountedPopup ? index : -1
    const changed = next !== this.active
    this.active = next
    this.paintActive()
    if (changed) {
      const el = this.shown?.[next]
      this.emit("item-highlighted", { value: el ? this.records.get(el).key : undefined, index: next, reason: reason === "keyboard" || reason === "pointer" ? reason : "none" }, { cancelable: false })
    }
    if (next >= 0 && (scroll || !this.pointerModality)) this.shown[next].scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  paintActive() {
    if (!this.mountedPopup) return
    this.shown.forEach((el, index) => el.toggleAttribute("data-highlighted", index === this.active))
    const id = this.active >= 0 ? this.shown[this.active]?.id : null
    const inputs = [this.control, this.mountedPopup.input].filter(Boolean)
    for (const el of this.inPopup ? [...inputs, this.mountedPopup.list] : inputs) id ? el.setAttribute("aria-activedescendant", id) : el.removeAttribute("aria-activedescendant")
  }

  // --- keyboard ------------------------------------------------------------------------------------------------------------

  keydown(event) {
    this.pointerModality = false
    const target = event.target
    if (target === this.field || target === this.control) return this.inputKeydown(event)
    if (target === this.trigger && this.inPopup) return this.triggerKeydown(event)
    if (target.matches?.("[data-slot=combobox-chip]")) return this.chipKeydown(event)
    if (target.matches?.(part("chip-remove"))) return this.chipRemoveKeydown(event)
  }

  inputKeydown(event) {
    if (event.which === 229 || event.isComposing) return
    if (!this.cfg.disabled) this.navigationKeydown(event)
    if (event.ctrlKey || event.shiftKey || event.altKey || event.metaKey) return
    if (this.cfg.disabled || this.cfg.readOnly) {
      if (this.cfg.readOnly && event.key === "Enter" && this.isOpen && this.active !== -1) this.stop(event)
      return
    }
    const input = event.target
    if (event.key === "Home" || event.key === "End") {
      this.stop(event)
      const at = event.key === "Home" ? 0 : input.value.length
      input.setSelectionRange(at, at)
      input.scrollLeft = event.key === "Home" ? 0 : input.scrollWidth - input.clientWidth
      return
    }
    if (!this.mountedPopup && event.key === "Escape" && !event.defaultPrevented) return this.escapeClear(event)
    if (!this.single && this.chips && event.key === "Backspace" && input.value === "" && this.selected.length) return this.removeLastChip(event)
    if (!this.single && this.chips && event.key === this.previousChipKey && (input.selectionStart ?? 0) === 0 && this.selected.length) {
      event.preventDefault()
      this.chipElements().at(-1)?.focus()
      return
    }
    if (event.key === "Tab" && this.inPopup && this.isOpen) return this.requestOpen(false, "focus-out", event)
    if (event.key === "Enter" && this.isOpen) {
      if (this.active === -1) return this.requestOpen(false, "none", event)
      this.stop(event)
      this.clickActive(event)
    }
  }

  // Escape on a closed input clears the text and the selection (input:L286-296).
  escapeClear(event) {
    const isClear = this.selected.length === 0
    this.setText("", "escape-key")
    this.setSelected([], "escape-key")
    if (!isClear) event.stopPropagation()
  }

  removeLastChip(event) {
    const chips = this.chipElements()
    const index = chips.length > 0 ? chips.length - 1 : this.selected.length - 1
    this.setActive(-1, "keyboard", event)
    this.setSelected(this.selected.filter((_, i) => i !== index), "none")
  }

  get previousChipKey() {
    return getComputedStyle(this.element).direction === "rtl" ? "ArrowRight" : "ArrowLeft"
  }

  get nextChipKey() {
    return this.previousChipKey === "ArrowLeft" ? "ArrowRight" : "ArrowLeft"
  }

  chipElements() {
    return [...(this.chips?.querySelectorAll("[data-slot=combobox-chip]") ?? [])]
  }

  stop(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  // useListNavigation on the input (virtual focus): ArrowDown/ArrowUp open the popup and move the highlight.
  navigationKeydown(event) {
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return
    this.stop(event)
    if (!this.isOpen) return this.requestOpen(true, "list-navigation", event)
    if (!this.mountedPopup || this.shown.length === 0) return
    const decrement = event.key === "ArrowUp"
    const max = this.shown.length - 1
    const current = this.active
    let next
    if (!this.cfg.loopFocus) next = decrement ? Math.max(0, current - 1) : Math.min(max, current + 1)
    else if (decrement ? current <= 0 : current >= max) {
      const outside = decrement ? -1 : this.shown.length
      next = this.cfg.autoHighlight === false && current !== outside ? -1 : decrement ? max : 0
    } else {
      next = current + (decrement ? -1 : 1)
    }
    this.setActive(next, "keyboard", event)
  }

  triggerKeydown(event) {
    this.triggerPointer = null
    if (this.cfg.disabled) return
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      this.stop(event)
      this.requestOpen(true, "list-navigation", event)
      return
    }
    if (this.isOpen || this.cfg.readOnly || !this.single || event.key.length !== 1 || event.ctrlKey || event.metaKey || event.altKey) return
    this.typeahead(event)
  }

  // useTypeahead on the closed trigger (trigger:L92-107): a printable key selects the next item whose label starts with the buffer.
  typeahead(event) {
    const items = this.cfg.items
    if (!items.length) return
    this.typeaheadBuffer ??= typeahead({ timeout: TYPEAHEAD_RESET_MS, onSearch: (search) => this.typeaheadSearch(search) })
    const buffer = this.typeaheadBuffer
    if (buffer.search === "") {
      this.typeaheadFrom = items.findIndex(({ k }) => this.selected.includes(k))
    } else if (buffer.search === event.key) {
      // A repeated key cycles: the buffer restarts from the current match.
      buffer.reset()
      this.typeaheadFrom = this.typeaheadMatch ?? this.typeaheadFrom
    }
    this.typeaheadFound = false
    buffer.push(event.key)
    if (!this.typeaheadFound) buffer.reset()
  }

  // Next item after the typeahead start whose label starts with `search` (wraps around); selects it.
  typeaheadSearch(search) {
    const items = this.cfg.items
    const start = (this.typeaheadFrom ?? -1) + 1
    const needle = search.toLowerCase()
    for (let offset = 0; offset < items.length; offset += 1) {
      const index = (start + offset) % items.length
      if (!items[index].l.toLowerCase().startsWith(needle)) continue
      this.typeaheadMatch = index
      this.typeaheadFound = true
      this.setSelected([items[index].k], "none")
      return
    }
  }

  chipKeydown(event) {
    if (this.cfg.disabled || this.cfg.readOnly) return
    const chips = this.chipElements()
    const index = chips.indexOf(event.target)
    let next = index
    if (event.key === this.previousChipKey) {
      event.preventDefault()
      next = index > 0 ? index - 1 : undefined
    } else if (event.key === this.nextChipKey) {
      event.preventDefault()
      next = index < chips.length - 1 ? index + 1 : undefined
    } else if (event.key === "Backspace" || event.key === "Delete") {
      next = index >= this.selected.length - 1 ? this.selected.length - 2 : index
      if (next < 0) next = undefined
      this.stop(event)
      this.setActive(-1, "keyboard", event)
      this.setSelected(this.selected.filter((_, i) => i !== index), "none")
    } else if (event.key === "Enter" || event.key === " ") {
      this.stop(event)
      next = undefined
    } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      this.stop(event)
      this.requestOpen(true, "list-navigation", event)
      next = undefined
    } else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
      next = undefined
    }
    if (next === undefined) this.control?.focus()
    else this.chipElements()[next]?.focus()
  }

  chipRemoveKeydown(event) {
    if (event.key !== "Enter" && event.key !== " ") return
    this.stop(event)
    this.removeChip(event.target.closest("[data-slot=combobox-chip]"), event)
  }

  removeChip(chip, event) {
    if (!chip || this.cfg.disabled || this.cfg.readOnly) return
    const index = this.chipElements().indexOf(chip)
    const key = this.selected[index]
    const el = this.shown?.[this.active]
    if (el && this.records.get(el)?.key === key) this.setActive(-1, "pointer", event)
    this.setSelected(this.selected.filter((_, i) => i !== index), "chip-remove-press")
    this.element.querySelector(part("input"))?.focus()
  }

  // --- pointer ---------------------------------------------------------------------------------------------------------------

  pointerdown(event) {
    if (event.target === this.control || event.target.closest?.(part("trigger"))) this.pointerDownAt = performance.now()
    if (event.target.closest?.(part("trigger"))) this.triggerPointer = event.pointerType || "mouse"
    const item = event.target.closest?.(part("item"))
    if (item && this.records?.has(item)) {
      if (event.isPrimary !== false) this.pointerDownItem = item
      event.preventDefault()
    }
  }

  mousedown(event) {
    const target = event.target
    if (target.closest?.(part("item"))) return event.preventDefault()
    if (target.closest?.(part("clear")) || target.closest?.(part("chip-remove"))) return event.preventDefault()
    if (event.button !== 0) return
    const trigger = target.closest?.(part("trigger"))
    if (trigger) return this.triggerPress(trigger, event)
    if (target === this.control) {
      if (!this.cfg.disabled && this.cfg.openOnInputClick) this.requestOpen(true, "input-press", event)
      return
    }
    const chips = target.closest?.(part("chips"))
    if (chips && !(target !== chips && target.closest(INTERACTIVE) && chips.contains(target.closest(INTERACTIVE)))) this.chipsPress(chips, event)
  }

  // Trigger mouse down toggles the popup and moves focus to the input, without stealing it back (trigger:L109-113, L169-184).
  triggerPress(trigger, event) {
    if (this.cfg.disabled || trigger.hasAttribute("disabled")) return
    // Next to an input the button never takes the focus; a standalone trigger keeps it until the popup's search field takes over.
    if (!this.inPopup) event.preventDefault()
    this.field?.focus()
    this.requestOpen(!this.isOpen, "trigger-press", event)
  }

  // A click with no pointer press before it is a keyboard activation (Enter/Space): it toggles like the mouse down does
  // (useClick:105-120). After a pointer press the mouse down already toggled.
  triggerClick(trigger, event) {
    if (this.triggerPointer) {
      this.triggerPointer = null
      return
    }
    if (this.cfg.disabled || trigger.hasAttribute("disabled")) return
    this.field?.focus()
    this.requestOpen(!this.isOpen, "trigger-press", event)
  }

  chipsPress(chips, event) {
    event.preventDefault()
    if (this.cfg.disabled) return
    this.element.querySelector(part("input"))?.focus()
    if (this.cfg.openOnInputClick) this.requestOpen(true, "input-press", event)
  }

  clicked(event) {
    const target = event.target
    const item = target.closest?.(part("item"))
    if (item && this.records?.has(item)) return this.itemClick(item, event)
    const trigger = target.closest?.(part("trigger"))
    if (trigger) return this.triggerClick(trigger, event)
    const clear = target.closest?.(part("clear"))
    if (clear) return this.clearPress(clear, event)
    const remove = target.closest?.(part("chip-remove"))
    if (remove) {
      this.removeChip(remove.closest("[data-slot=combobox-chip]"), event)
      event.stopPropagation()
    }
  }

  clearPress(clear, event) {
    if (this.cfg.disabled || this.cfg.readOnly || clear.hasAttribute("disabled")) return
    this.setText("", "clear-press")
    this.setSelected([], "clear-press")
    this.setActive(-1, "pointer", event)
    ;(this.control ?? this.element.querySelector(part("input")))?.focus()
  }

  itemClick(item, event, { keyEvent = null } = {}) {
    const record = this.records.get(item)
    if (record.disabled || this.cfg.disabled || this.cfg.readOnly) return
    this.selectItem(record.key, keyEvent ?? event)
    if (this.cfg.submitOnItemClick) this.element.closest("form")?.requestSubmit()
  }

  mouseup(event) {
    const item = event.target.closest?.(part("item"))
    if (!item || !this.records?.has(item)) return
    const startedHere = this.pointerDownItem === item
    this.pointerDownItem = null
    const record = this.records.get(item)
    if (record.disabled || this.cfg.readOnly || this.cfg.disabled || event.button !== 0 || startedHere || this.shown[this.active] !== item) return
    this.selectItem(record.key, event)
  }

  clickActive(event) {
    const item = this.shown[this.active]
    if (item) this.itemClick(item, event, { keyEvent: event })
  }

  // handleSelection (root:L664-710).
  selectItem(key, event) {
    const query = this.query()
    if (!this.single) {
      const present = this.selected.includes(key)
      const next = present ? this.selected.filter((k) => k !== key) : [...this.selected, key]
      if (!this.setSelected(next, "item-press")) return
      const filtering = (this.field?.value ?? "").trim() !== ""
      if (!filtering) return
      if (this.inPopup) {
        this.setText("", "input-clear")
        if (!present) this.pendingToggled = key
        this.restoreHighlightAfterClear(key)
      } else {
        this.requestOpen(false, "item-press", event, { query })
      }
      return
    }
    if (!this.setSelected([key], "item-press")) return
    this.requestOpen(false, "item-press", event, { query })
  }

  restoreHighlightAfterClear(toggled) {
    const index = this.shown.findIndex((el) => this.records.get(el).key === toggled)
    if (index >= 0) this.setActive(index, "none")
  }

  mousemove(event) {
    if (!this.isOpen || !this.mountedPopup || !this.cfg.highlightItemOnHover) return
    const item = event.target.closest?.(part("item"))
    if (!item || !this.records.has(item)) return
    this.pointerModality = true
    const index = this.shown.indexOf(item)
    if (index !== this.active) this.setActive(index, "pointer", event)
  }

  pointerout(event) {
    if (!this.isOpen || !this.pointerModality || event.pointerType === "touch" || !this.cfg.highlightItemOnHover || this.cfg.keepHighlight) return
    const item = event.target.closest?.(part("item"))
    if (!item || !this.records?.has(item) || item.contains(event.relatedTarget)) return
    if (this.shown.includes(event.relatedTarget)) return
    this.setActive(-1, "pointer", event)
  }

  // Focus leaving the input for an unrelated element closes the popup (ffm:L286-320).
  focusedOut(event) {
    if (!this.isOpen || event.target !== this.field) return
    const next = event.relatedTarget
    if (!next || this.mountedPopup?.container.contains(next) || this.element.contains(next) && next === this.trigger) return
    if (this.pointerDownAt && performance.now() - this.pointerDownAt < 50) return
    this.requestOpen(false, "focus-out", event)
  }
}
