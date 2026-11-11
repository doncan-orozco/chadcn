import { Controller } from "@hotwired/stimulus"
import { collatorContains, filterQuery, matchItems, triggerTypeahead } from "chadcn/primitives/combobox_filter"
import { chipArrowKeys, withoutIndex } from "chadcn/primitives/combobox_navigation"
import { ComboboxPopup, markControls, part, syncDismissStart } from "chadcn/primitives/combobox_popup"
import { ComboboxState } from "chadcn/primitives/combobox_state"
import { ComboboxValue } from "chadcn/primitives/combobox_value"
import { presence } from "chadcn/primitives/presence"

// shadcn Combobox: a hand-written equivalent of Base UI 1.9.0 `Combobox` (no third-party JavaScript). Spec:
// dev/port/specs/combobox.md (Behavior); the `root:` / `input:` / `nav:` citations of the comments point at the Base UI sources the spec cites.
// The server renders the host, the parts that are always in the document (input, trigger, chips, clear, hidden inputs) and the popup
// in an inert <template>; the controller mounts that template into `body > div[data-base-ui-portal]` while open and wires the
// engine of primitives/combobox_*: the state machine (combobox_state: selection, text, query, open requests, highlight), matching
// (combobox_filter), navigation steps (combobox_navigation), the mounted popup and its list (combobox_popup) and the parts that
// show or submit the selection (combobox_value). This controller keeps the lifecycle, the values, the listeners and the events.
//
// State of the host (Stimulus values, written back so a Turbo snapshot restores it): `selected` (form values of the selection),
// `open`, `inputValue`. `config` is static. With `value:` / `open:` / `input_value:` given the matching value is CONTROLLED: the events fire
// and the DOM waits for the caller to change the attribute.
//
// Events (prefix chadcn--combobox:, bubbling; cancelable ones map Base UI's `eventDetails.cancel()` to preventDefault()):
// `value-change` { value, reason } (value = the item's form value), `open-change` { open, reason }, `input-value-change`
// { inputValue, reason }, `item-highlighted` { value, index, reason } and `open-change-complete` { open } (not cancelable).
//
// Known divergences: item identity on the client is the form value (equality callables run on the server, see Combobox::Model); the
// modal popup traps no focus (the input keeps it; Tab leaves and closes, like the non-modal popup); `value-change` carries the form value, not the
// item object; the closed-trigger typeahead and the autofill match use the form value / label of the item.

const TYPEAHEAD_RESET_MS = 750
const DISMISS_LABEL = "Dismiss"
const CHIP = "[data-slot=combobox-chip]"
const INTERACTIVE = "button,a[href],[role=\"button\"],select,[tabindex]:not([tabindex=\"-1\"]),input,textarea"

export default class extends Controller {
  static values = { config: Object, selected: Array, open: Boolean, inputValue: String }

  connect() {
    this.cfg = this.configValue
    this.template = this.element.querySelector(part("content-template"))
    this.abort = new AbortController()
    const { signal } = this.abort
    this.labels = new Map([...this.cfg.items, ...(this.cfg.extras ?? [])].map(({ k, l }) => [k, l]))
    this.control = this.element.querySelector(part("input"))
    this.inPopup = !this.control
    this.mountedPopup = null
    this.options = JSON.parse(this.template?.getAttribute("data-chadcn--combobox-options") ?? "{}")
    this.contains = collatorContains(this.cfg.locale)
    this.valueParts = new ComboboxValue(this.element, { ...this.cfg, single: this.single }, this.selectedValue)
    this.state = new ComboboxState({
      single: this.single,
      inPopup: this.inPopup,
      selected: this.selectedValue,
      // A search field inside the popup starts empty (Base UI clears it when it mounts) unless the caller gave its text.
      text: this.inPopup && !this.cfg.inputValueGiven ? "" : this.inputValueValue,
      controlled: { value: this.cfg.valueControlled, inputValue: this.cfg.inputValueControlled, open: this.cfg.openControlled }
    }, this.stateHost())
    this.listen(this.element, signal)
    this.valueParts.hidden?.addEventListener("focus", () => (this.field ?? this.trigger)?.focus(), { signal })
    this.valueParts.hidden?.addEventListener("change", (event) => this.autofill(event), { signal })
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
    this.typeahead?.release()
    this.typeahead = null
    this.abort = null
  }

  // What the state machine asks of the document.
  stateHost() {
    return {
      emit: (name, detail, options) => this.dispatch(name, { detail, cancelable: options?.cancelable ?? true }).defaultPrevented,
      labelOf: (key) => this.label(key),
      canOpen: (next) => Boolean(this.template) && !(next && this.cfg.disabled),
      selectionChanged: (selected) => {
        this.selectedValue = [...selected]
        this.renderSelection()
      },
      writeText: (text, { store }) => this.writeText(text, { store }),
      queryChanged: () => this.afterQueryChange(),
      openChanged: (next, reason, event) => {
        this.openValue = next
        this.applyOpen(next, reason, event)
      },
      shownKeys: () => this.shown.map((el) => this.record(el).key),
      shownDisabled: () => this.shown.map((el) => this.record(el).disabled),
      mounted: () => Boolean(this.mountedPopup),
      paintHighlight: () => this.paintActive(),
      scrollToShown: (index) => this.shown[index].scrollIntoView({ block: "nearest", inline: "nearest" })
    }
  }

  // --- Stimulus values: controlled changes -----------------------------------------------------------------------------

  openValueChanged(value) {
    if (!this.ready || value === this.state.isOpen) return
    if (this.cfg.disabled && value) return
    this.applyOpen(value, "none", null, { focus: false })
  }

  selectedValueChanged(value) {
    if (!this.ready) return
    const next = [...value]
    if (next.join("\u0000") === this.selected.join("\u0000")) return
    this.state.selected = next
    this.renderSelection()
  }

  inputValueValueChanged(value) {
    if (!this.ready || value === this.state.text) return
    this.state.applyText(value)
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
    on("pointermove", () => { this.state.pointerModality = true })
    on("mousemove", (event) => this.mousemove(event))
    on("pointerout", (event) => this.pointerout(event))
    on("mouseup", (event) => this.mouseup(event))
    on("compositionend", (event) => this.typed(event))
  }

  get single() {
    return !this.cfg.multiple
  }

  /** The selection (form values); read by the browser tests. */
  get selected() {
    return this.state.selected
  }

  get field() {
    return this.inPopup ? this.mountedPopup?.input : this.control
  }

  get trigger() {
    return this.element.querySelector(part("trigger"))
  }

  get shown() {
    return this.mountedPopup?.shown ?? []
  }

  record(el) {
    return this.mountedPopup?.records.get(el)
  }

  label(key) {
    return this.labels.get(key) ?? key
  }

  // --- query, filter (root:L225-330) -------------------------------------------------------------------------------------

  // The list items that match (null: no `items:`, the static children are all shown and nothing is filtered), memoized per query:
  // several callers ask for it on every keystroke. `cfg` is read on every miss (the browser tests switch the filter at runtime).
  matchResult() {
    if (!this.cfg.hasItems) return null
    const { selectedLabel, single, queryEdited } = this.state
    const query = filterQuery(this.state.query(), { selectedLabel, single, queryEdited, contains: this.contains })
    if (this.matchCache?.query !== query) this.matchCache = matchItems(this.cfg.items, query, { filter: this.cfg.filter, limit: this.cfg.limit, contains: this.contains })
    return this.matchCache
  }

  get listEmpty() {
    return !this.matchResult()?.list.length
  }

  // --- selection and text (root:L350-420) ---------------------------------------------------------------------------------

  renderSelection() {
    this.valueParts.render(this.selected, { labelOf: (key) => this.label(key) })
    this.syncControls()
    this.valueParts.syncClear(this.selected.length > 0, this.state.isOpen)
    this.mountedPopup?.renderItemStates(this.selected)
  }

  // Native autofill writes the label or value of an option into the hidden input (root:L1231-1281).
  autofill(event) {
    if (this.valueParts.writing || event.defaultPrevented || this.cfg.disabled || this.cfg.readOnly || !this.single) return
    const item = this.valueParts.autofilled(this.cfg.items)
    if (item) queueMicrotask(() => this.state.setSelected([item.k], "none"))
  }

  writeText(text, { store }) {
    if (store) this.inputValueValue = text
    for (const input of [this.control, this.mountedPopup?.input]) {
      if (!input) continue
      if (input.value !== text) input.value = text
      input.setAttribute("value", text)
    }
  }

  // The input fires `input` for typing and for IME commits; autofill-like input does not open the popup (input:L195-257).
  typed(event) {
    const input = event.target
    if (!input.matches?.(part("input")) || event.isComposing || this.cfg.disabled) return
    const value = input.value
    const typed = event.type === "compositionend" || (event.inputType != null && event.inputType !== "" && event.inputType !== "insertReplacementText")
    const query = typed && value.trim() !== ""
    this.state.typed()
    if (!this.state.setText(value, "input-change")) return input.value = this.state.text
    if (query) {
      this.state.markEdited()
      this.afterQueryChange()
      if (this.mountedPopup?.list) this.mountedPopup.list.scrollTop = 0
    }
    if (value === "" && !this.inPopup) {
      if (this.single) this.state.setSelected([], "input-clear")
      if (!this.cfg.openOnInputClick) this.state.requestOpen(false, "input-clear", event)
    }
    if (query && !this.cfg.readOnly) {
      this.state.requestOpen(true, "input-change", event)
      if (!this.cfg.autoHighlight) this.state.setActive(-1, "keyboard", event)
    }
    if (this.state.isOpen && this.state.active !== -1 && !this.cfg.autoHighlight) this.state.setActive(-1, "keyboard", event)
    if (query && this.cfg.autoHighlight && this.mountedPopup && this.shown.length) this.state.setActive(0, "keyboard", event)
  }

  // --- open / close (root:L580-650, popup mount) ------------------------------------------------------------------------

  applyOpen(next, reason, event, { focus = true } = {}) {
    if (next === this.state.isOpen && (!next || this.mountedPopup)) return
    this.state.isOpen = next
    if (next) {
      this.mountedPopup ? this.reopenPopup() : this.mountPopup({ focus })
      this.state.openHighlight(reason, event?.type === "keydown" ? event.key : null, this.cfg.autoHighlight)
    } else if (this.mountedPopup) {
      this.closeReason = reason
      this.mountedPopup.markClosed(this.listEmpty)
    }
    this.syncControls()
    this.valueParts.syncClear(this.selected.length > 0, this.state.isOpen)
    this.syncDismissStart()
  }

  syncControls() {
    markControls({
      control: this.control, trigger: this.trigger, popup: this.mountedPopup, open: this.state.isOpen, empty: this.listEmpty,
      placeholder: this.selected.length === 0, inPopup: this.inPopup, id: this.cfg.id
    })
  }

  syncDismissStart() {
    syncDismissStart(this.element, this.control, this.state.isOpen, DISMISS_LABEL)
  }

  mountPopup({ focus }) {
    const reference = this.inPopup ? this.trigger : this.control
    const popup = (this.mountedPopup = new ComboboxPopup(this.template, {
      side: this.options.side, align: this.options.align, empty: this.listEmpty, modal: this.cfg.modal, inPopup: this.inPopup, cutout: reference
    }))
    this.listen(popup.positioner, popup.listeners.signal)
    this.state.pointerModality = true
    this.renderList()
    popup.renderItemStates(this.selected)
    popup.announce(this.listEmpty)
    const { side, sideOffset, align, alignOffset } = this.options
    const anchor = (this.options.anchor && document.querySelector(this.options.anchor)) || reference
    popup.place(anchor, { side, sideOffset, align, alignOffset, dir: getComputedStyle(this.element).direction }, (placed) => {
      for (const el of [this.control, this.trigger]) el?.setAttribute("data-popup-side", placed)
    })
    popup.addDismissEnd(DISMISS_LABEL, (event) => this.state.requestOpen(false, "close-press", event))
    popup.addFocusGuards(this.trigger, (event) => this.state.requestOpen(false, "focus-out", event))
    this.openLayers()
    popup.presence = presence(popup.popup, { onExited: () => this.unmountPopup() })
    popup.seedInput(this.state.text, focus)
    this.syncControls()
  }

  // Outside press / Escape close the popup; the input, trigger, chips, clear button and hidden input are not "outside".
  openLayers() {
    this.mountedPopup.openLayers({
      branches: () => [this.trigger, this.element.querySelector(part("clear")), this.valueParts.chipsRoot, this.control, this.valueParts.hidden].filter(Boolean),
      keep: [this.control, this.element.querySelector(part("dismiss-start"))].filter(Boolean),
      ariaHidden: !this.inPopup || this.cfg.modal,
      onDismiss: (reason, event) => this.state.requestOpen(false, reason, event)
    })
  }

  reopenPopup() {
    this.mountedPopup.markOpen()
    this.openLayers()
    this.renderList()
  }

  // handleUnmountCleanup (root:L717-756) plus the focus the popup returns to its trigger.
  unmountPopup({ immediate = false } = {}) {
    const popup = this.mountedPopup
    if (!popup) return
    if (!immediate) this.state.setActive(-1, "none")
    this.mountedPopup = null
    popup.teardown()
    this.state.active = -1
    this.element.querySelectorAll(part("input")).forEach((input) => input.removeAttribute("aria-activedescendant"))
    if (immediate) {
      this.state.isOpen = false
      return
    }
    this.dispatch("open-change-complete", { detail: { open: false }, cancelable: false })
    this.state.finish()
    if (this.inPopup && !["focus-out", "outside-press"].includes(this.closeReason)) this.trigger?.focus({ preventScroll: true })
    this.syncControls()
  }

  // Turbo snapshot / disconnect: a cached page shows the closed server state with the current selection.
  reset() {
    if (!this.abort) return
    const wasOpen = this.state.isOpen
    this.unmountPopup({ immediate: true })
    this.state.isOpen = false
    this.state.reset()
    this.matchCache = null
    this.valueParts.resetClear(this.selected.length > 0)
    if (wasOpen && !this.cfg.openControlled) this.openValue = false
    if (this.single && !this.inPopup && !this.cfg.inputValueControlled) this.state.applyText(this.state.selectedLabel)
    this.syncControls()
    this.valueParts.syncClear(this.selected.length > 0, this.state.isOpen)
    this.syncDismissStart()
  }

  // --- the list inside the popup ------------------------------------------------------------------------------------------

  afterQueryChange() {
    if (this.mountedPopup) this.renderList()
    else this.syncControls()
  }

  renderList() {
    const popup = this.mountedPopup
    const result = this.matchResult()
    if (!popup?.renderList(result ? new Set(result.list.map(({ k }) => k)) : null, result?.scores ?? null, this.cfg.id)) return
    popup.syncEmpty(this.listEmpty)
    this.syncControls()
    if (this.state.active >= this.shown.length) this.state.setActive(-1, "none")
    else this.paintActive()
    if (this.cfg.autoHighlight === "always" && this.state.active === -1 && this.shown.length) this.state.setActive(0, "none")
  }

  paintActive() {
    const popup = this.mountedPopup
    if (!popup) return
    const inputs = [this.control, popup.input].filter(Boolean)
    popup.paintActive(this.state.active, this.inPopup ? [...inputs, popup.list] : inputs)
  }

  // --- keyboard ------------------------------------------------------------------------------------------------------------

  keydown(event) {
    this.state.pointerModality = false
    const target = event.target
    if (target === this.field || target === this.control) return this.inputKeydown(event)
    if (target === this.trigger && this.inPopup) return this.triggerKeydown(event)
    if (target.matches?.(CHIP)) return this.chipKeydown(event)
    if (target.matches?.(part("chip-remove")) && (event.key === "Enter" || event.key === " ")) {
      this.stop(event)
      this.removeChip(target.closest(CHIP), event)
    }
  }

  inputKeydown(event) {
    if (event.which === 229 || event.isComposing) return
    if (!this.cfg.disabled) this.navigationKeydown(event)
    if (event.ctrlKey || event.shiftKey || event.altKey || event.metaKey) return
    if (this.cfg.disabled || this.cfg.readOnly) {
      if (this.cfg.readOnly && event.key === "Enter" && this.state.isOpen && this.state.active !== -1) this.stop(event)
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
    // Escape on a closed input clears the text and the selection (input:L286-296).
    if (!this.mountedPopup && event.key === "Escape" && !event.defaultPrevented) {
      const isClear = this.selected.length === 0
      this.state.clear("escape-key")
      if (!isClear) event.stopPropagation()
      return
    }
    const chips = !this.single && this.valueParts.chipsRoot && this.selected.length
    if (chips && event.key === "Backspace" && input.value === "") return this.removeAt((this.valueParts.chips().length || this.selected.length) - 1, event)
    if (chips && event.key === chipArrowKeys(getComputedStyle(this.element).direction).previous && (input.selectionStart ?? 0) === 0) {
      event.preventDefault()
      this.valueParts.chips().at(-1)?.focus()
      return
    }
    if (event.key === "Tab" && this.inPopup && this.state.isOpen) return this.state.requestOpen(false, "focus-out", event)
    if (event.key === "Enter" && this.state.isOpen) {
      if (this.state.active === -1) return this.state.requestOpen(false, "none", event)
      this.stop(event)
      const item = this.shown[this.state.active]
      if (item) this.itemClick(item, event)
    }
  }

  // Backspace / Delete on a chip, Backspace in an empty input: the highlight goes, then the value at `index`.
  removeAt(index, event) {
    this.state.setActive(-1, "keyboard", event)
    this.state.setSelected(withoutIndex(this.selected, index), "none")
  }

  stop(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  // useListNavigation on the input (virtual focus): ArrowDown/ArrowUp open the popup and move the highlight.
  navigationKeydown(event) {
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return
    this.stop(event)
    if (!this.state.isOpen) return this.state.requestOpen(true, "list-navigation", event)
    this.state.navigate(event.key === "ArrowUp", event, this.cfg)
  }

  triggerKeydown(event) {
    this.triggerPointer = null
    if (this.cfg.disabled) return
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      this.stop(event)
      this.state.requestOpen(true, "list-navigation", event)
      return
    }
    if (this.state.isOpen || this.cfg.readOnly || !this.single || event.key.length !== 1 || event.ctrlKey || event.metaKey || event.altKey) return
    // useTypeahead on the closed trigger (trigger:L92-107): a printable key selects the next item whose label starts with the buffer.
    this.typeahead ??= triggerTypeahead({ timeout: TYPEAHEAD_RESET_MS, onMatch: (item) => this.state.setSelected([item.k], "none") })
    this.typeahead.push(event.key, this.cfg.items, this.selected)
  }

  chipKeydown(event) {
    if (this.cfg.disabled || this.cfg.readOnly) return
    this.valueParts.chipKeydown(event, {
      selectedCount: this.selected.length,
      direction: getComputedStyle(this.element).direction,
      input: this.control,
      onRemove: (index) => this.removeAt(index, event),
      onOpen: () => this.state.requestOpen(true, "list-navigation", event)
    })
  }

  removeChip(chip, event) {
    if (!chip || this.cfg.disabled || this.cfg.readOnly) return
    const index = this.valueParts.chips().indexOf(chip)
    const el = this.shown[this.state.active]
    if (el && this.record(el)?.key === this.selected[index]) this.state.setActive(-1, "pointer", event)
    this.state.setSelected(withoutIndex(this.selected, index), "chip-remove-press")
    this.element.querySelector(part("input"))?.focus()
  }

  // --- pointer ---------------------------------------------------------------------------------------------------------------

  pointerdown(event) {
    if (event.target === this.control || event.target.closest?.(part("trigger"))) this.pointerDownAt = performance.now()
    if (event.target.closest?.(part("trigger"))) this.triggerPointer = event.pointerType || "mouse"
    const item = event.target.closest?.(part("item"))
    if (item && this.record(item)) {
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
    if (trigger) {
      // Trigger mouse down toggles the popup and moves focus to the input, without stealing it back (trigger:L109-113, L169-184).
      // Next to an input the button never takes the focus; a standalone trigger keeps it until the popup's search field takes over.
      if (this.cfg.disabled || trigger.hasAttribute("disabled")) return
      if (!this.inPopup) event.preventDefault()
      return this.toggleFromTrigger(event)
    }
    if (target === this.control) {
      if (!this.cfg.disabled && this.cfg.openOnInputClick) this.state.requestOpen(true, "input-press", event)
      return
    }
    // A press on the chips area (not on a control inside it) focuses the input and opens like an input press.
    const chips = target.closest?.(part("chips"))
    if (!chips || (target !== chips && target.closest(INTERACTIVE) && chips.contains(target.closest(INTERACTIVE)))) return
    event.preventDefault()
    if (this.cfg.disabled) return
    this.element.querySelector(part("input"))?.focus()
    if (this.cfg.openOnInputClick) this.state.requestOpen(true, "input-press", event)
  }

  toggleFromTrigger(event) {
    this.field?.focus()
    this.state.requestOpen(!this.state.isOpen, "trigger-press", event)
  }

  // A trigger click with no pointer press before it is a keyboard activation (Enter/Space): it toggles like the mouse down does
  // (useClick:105-120). After a pointer press the mouse down already toggled.
  triggerClick(trigger, event) {
    if (this.triggerPointer) {
      this.triggerPointer = null
      return
    }
    if (!this.cfg.disabled && !trigger.hasAttribute("disabled")) this.toggleFromTrigger(event)
  }

  clicked(event) {
    const target = event.target
    const item = target.closest?.(part("item"))
    if (item && this.record(item)) return this.itemClick(item, event)
    const trigger = target.closest?.(part("trigger"))
    if (trigger) return this.triggerClick(trigger, event)
    const clear = target.closest?.(part("clear"))
    if (clear) return this.clearPress(clear, event)
    const remove = target.closest?.(part("chip-remove"))
    if (remove) {
      this.removeChip(remove.closest(CHIP), event)
      event.stopPropagation()
    }
  }

  clearPress(clear, event) {
    if (this.cfg.disabled || this.cfg.readOnly || clear.hasAttribute("disabled")) return
    this.state.clear("clear-press")
    this.state.setActive(-1, "pointer", event)
    ;(this.control ?? this.element.querySelector(part("input")))?.focus()
  }

  itemClick(item, event) {
    const record = this.record(item)
    if (record.disabled || this.cfg.disabled || this.cfg.readOnly) return
    this.selectItem(record.key, event)
    if (this.cfg.submitOnItemClick) this.element.closest("form")?.requestSubmit()
  }

  mouseup(event) {
    const item = event.target.closest?.(part("item"))
    const record = item && this.record(item)
    if (!record) return
    const startedHere = this.pointerDownItem === item
    this.pointerDownItem = null
    if (record.disabled || this.cfg.readOnly || this.cfg.disabled || event.button !== 0 || startedHere || this.shown[this.state.active] !== item) return
    this.selectItem(record.key, event)
  }

  selectItem(key, event) {
    this.state.select(key, event, { filtering: () => (this.field?.value ?? "").trim() !== "" })
  }

  mousemove(event) {
    if (!this.state.isOpen || !this.mountedPopup || !this.cfg.highlightItemOnHover) return
    const item = event.target.closest?.(part("item"))
    if (!item || !this.record(item)) return
    this.state.pointerModality = true
    const index = this.shown.indexOf(item)
    if (index !== this.state.active) this.state.setActive(index, "pointer", event)
  }

  pointerout(event) {
    if (!this.state.isOpen || !this.state.pointerModality || event.pointerType === "touch" || !this.cfg.highlightItemOnHover || this.cfg.keepHighlight) return
    const item = event.target.closest?.(part("item"))
    if (!item || !this.record(item) || item.contains(event.relatedTarget)) return
    if (this.shown.includes(event.relatedTarget)) return
    this.state.setActive(-1, "pointer", event)
  }

  // Focus leaving the input for an unrelated element closes the popup (ffm:L286-320).
  focusedOut(event) {
    if (!this.state.isOpen || event.target !== this.field) return
    const next = event.relatedTarget
    if (!next || this.mountedPopup?.container.contains(next) || this.element.contains(next) && next === this.trigger) return
    if (this.pointerDownAt && performance.now() - this.pointerDownAt < 50) return
    this.state.requestOpen(false, "focus-out", event)
  }
}
