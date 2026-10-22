import { Controller } from "@hotwired/stimulus"
import { ITEM_SELECTOR, isDisabled } from "chadcn/primitives/collection"
import { dismissable } from "chadcn/primitives/dismissable_layer"
import { focusGuards } from "chadcn/primitives/focus_guards"
import { focusScope } from "chadcn/primitives/focus_scope"
import { FormBubbleInput } from "chadcn/primitives/form_bubble_input"
import { hideOthers } from "chadcn/primitives/hide_others"
import { ensureWrapper, positioner } from "chadcn/primitives/positioner"
import { presence } from "chadcn/primitives/presence"
import { scrollLock } from "chadcn/primitives/scroll_lock"
import { mountTemplate } from "chadcn/primitives/template_mount"
import { matchItem, typeahead } from "chadcn/primitives/typeahead"

// Radix Select. Spec: docs/shadcn-port/specs/select.md (Behavior).
//
// The controller element is the Trigger. The Content ships in an inert <template> that connect() detaches: Radix mounts it
// (portaled to <body>) only while open, and keeps the items in a detached fragment otherwise, which here is the registry read
// from the template. Everything inside a mounted content is wired with delegated listeners on the content element, because
// the clone lives outside the controller scope.
//
// Known divergence: the focus trap does not switch off while the exit animation plays.
const TEMPLATE = "chadcn--select-template"
const OPEN_KEYS = [" ", "Enter", "ArrowUp", "ArrowDown"]
const SELECTION_KEYS = [" ", "Enter"]
const NAVIGATION_KEYS = ["ArrowUp", "ArrowDown", "Home", "End"]
const CONTENT_MARGIN = 10
const templates = new WeakMap() // trigger -> its detached template, so a reconnect finds it again

const blank = (value) => value === "" || value === undefined || value === null
const clamp = (value, [min, max]) => Math.min(max, Math.max(min, value))
const boundaries = (selectors) => (selectors ? [selectors].flat().flatMap((selector) => [...document.querySelectorAll(selector)]) : undefined)
const itemText = (item) => item.lastElementChild
const textOf = (item) => item.getAttribute("data-chadcn--select-text-value") || itemText(item).textContent.trim()

// The items as the closed Select knows them (Radix registers them in a detached fragment, sel:L285-299).
function registry(template) {
  return [...template.content.querySelectorAll(ITEM_SELECTOR)].map((item) => ({
    value: item.getAttribute("data-chadcn--select-value"),
    disabled: isDisabled(item),
    html: itemText(item).innerHTML,
    label: itemText(item).textContent,
    textValue: textOf(item)
  }))
}

class SelectContent {
  constructor(select, template, { open = true } = {}) {
    this.select = select
    this.template = template
    this.options = JSON.parse(template.getAttribute("data-options") || "{}")
    this.popper = this.options.position === "popper"
    this.isOpen = open
    this.abort = new AbortController()
    this.releases = []
    this.pointerTypes = new WeakMap()
    this.buttons = []
    this.isPositioned = false
    this.shouldReposition = true
    this.shouldExpandOnScroll = false
    this.previousScrollTop = 0
    this.scrollTimer = null
  }

  mount() {
    this.mounted = mountTemplate(this.template, { into: document.body })
    this.content = this.mounted.nodes[0]
    this.viewport = this.content.querySelector("[data-radix-select-viewport]")
    this.#detachButtons()
    this.wrapper = this.popper ? ensureWrapper(this.content) : this.#alignedWrapper()
    this.content.dataset.state = this.isOpen ? "open" : "closed"
    this.applySelection()
    this.#pickSelected()
    this.search = typeahead({ onSearch: (search) => this.#search(search) })
    this.releases.push(() => this.search.release())
    this.#bind()
    this.#effects()
    this.#place()
    this.presence = presence(this.content, { onExited: () => this.teardown() })
    this.releases.push(() => this.presence.release())
  }

  // Begin the exit: the state flips now, the node stays until its exit animation ends (Presence).
  close() {
    if (!this.isOpen) return
    this.isOpen = false
    this.content.dataset.state = "closed"
    // Radix recreates the position callback on every render (inline onPlaced), so its layout effect places again.
    if (!this.popper) this.#position()
    if (!this.options.forceMount) this.presence.exit() // Presence stays present with force_mount
  }

  reopen() {
    this.isOpen = true
    this.content.dataset.state = "open"
    this.presence.enter()
  }

  teardown() {
    if (this.gone) return
    this.gone = true
    this.abort.abort()
    window.clearInterval(this.scrollTimer)
    this.releases.reverse().forEach((release) => release())
    this.buttons.forEach(({ node, marker }) => { node.remove(); marker.remove() })
    this.wrapper.remove()
    this.select.content = null
  }

  // Item state follows the current value (the template was rendered with the value of the first paint).
  applySelection() {
    this.#items().forEach((item) => {
      const selected = !blank(this.select.value) && item.getAttribute("data-chadcn--select-value") === this.select.value
      item.dataset.state = selected ? "checked" : "unchecked"
      const indicator = item.querySelector('[data-slot="select-item-indicator"]')
      if (selected && !indicator.firstElementChild) indicator.innerHTML = this.template.getAttribute("data-chadcn--select-indicator")
      else if (!selected) indicator.replaceChildren()
      if (item.hasAttribute("data-highlighted")) item.setAttribute("aria-selected", String(selected))
    })
  }

  // --- structure -----------------------------------------------------------------------------------------------------

  // Radix mounts a scroll button only while the viewport can scroll that way: the node waits out of the document.
  #detachButtons() {
    this.content.querySelectorAll('[data-slot="select-scroll-up-button"], [data-slot="select-scroll-down-button"]').forEach((node) => {
      const marker = document.createComment("")
      node.replaceWith(marker)
      this.buttons.push({ node, marker, kind: node.dataset.slot.includes("-up-") ? "up" : "down", shown: false })
      this.#bindButton(node)
    })
  }

  #alignedWrapper() {
    const wrapper = document.createElement("div")
    this.content.before(wrapper)
    wrapper.append(this.content)
    Object.assign(wrapper.style, { display: "flex", flexDirection: "column", position: "fixed", zIndex: getComputedStyle(this.content).zIndex })
    return wrapper
  }

  #items() { return [...this.content.querySelectorAll(ITEM_SELECTOR)] }
  #enabled() { return this.#items().filter((item) => !isDisabled(item)) }
  #itemOf(target) { return target.closest?.(ITEM_SELECTOR) ?? null }

  // itemRefCallback / itemTextRefCallback (sel:L415-436): the selected item, or the first enabled one; the last match wins.
  #pickSelected() {
    let firstFound = false
    this.selectedItem = null
    this.#items().forEach((item) => {
      const first = !firstFound && !isDisabled(item)
      const selected = !blank(this.select.value) && item.getAttribute("data-chadcn--select-value") === this.select.value
      if (!selected && !first) return
      this.selectedItem = item
      this.selectedText = itemText(item)
      if (first) firstFound = true
    })
  }

  // --- effects, children first like Radix ---------------------------------------------------------------------------

  #effects() {
    const select = this.select
    this.releases.push(
      dismissable(this.content, {
        disableOutsidePointerEvents: true,
        onEscape: (event) => this.#forward("escape-key-down", event),
        onPointerDownOutside: (event) => this.#forward("pointer-down-outside", event),
        onFocusOutside: (event) => event.preventDefault(),
        onDismiss: () => select.requestOpen(false)
      }),
      focusScope(this.content, {
        trapped: true,
        onMountAutoFocus: (event) => event.preventDefault(),
        onUnmountAutoFocus: (event) => {
          event.preventDefault()
          if (select.disconnecting) return
          if (!select.dispatch("close-auto-focus").defaultPrevented) select.element.focus({ preventScroll: true })
        }
      }),
      scrollLock(),
      focusGuards(),
      hideOthers(this.content)
    )

    const close = () => select.requestOpen(false)
    window.addEventListener("blur", close)
    window.addEventListener("resize", close)
    this.releases.push(() => {
      window.removeEventListener("blur", close)
      window.removeEventListener("resize", close)
    })
    this.#watchPointer()
  }

  // Re-emit a primitive event as a public cancelable event; a prevented one keeps the primitive from dismissing.
  #forward(name, event) {
    const originalEvent = event.detail?.originalEvent ?? event
    if (this.select.dispatch(name, { detail: { originalEvent } }).defaultPrevented) event.preventDefault()
  }

  // Press on the trigger, drag, release (sel:L367-397): a short move keeps the select open, a long one releases like a click.
  #watchPointer() {
    const select = this.select
    if (select.pointerDownPos === null) return
    let delta = { x: 0, y: 0 }
    const move = (event) => {
      delta = { x: Math.abs(Math.round(event.pageX) - (select.pointerDownPos?.x ?? 0)), y: Math.abs(Math.round(event.pageY) - (select.pointerDownPos?.y ?? 0)) }
    }
    const up = (event) => {
      if (delta.x <= 10 && delta.y <= 10) event.preventDefault()
      else if (!event.composedPath().includes(this.content)) select.requestOpen(false)
      document.removeEventListener("pointermove", move)
      select.pointerDownPos = null
    }
    document.addEventListener("pointermove", move)
    document.addEventListener("pointerup", up, { capture: true, once: true })
    this.releases.push(() => {
      document.removeEventListener("pointermove", move)
      document.removeEventListener("pointerup", up, { capture: true })
    })
  }

  // --- positioning ---------------------------------------------------------------------------------------------------

  #place() {
    if (!this.popper) return this.#position()
    const o = this.options
    const placement = positioner(this.select.element, this.content, {
      side: o.side, sideOffset: o.sideOffset, align: o.align, alignOffset: o.alignOffset, arrowPadding: o.arrowPadding,
      avoidCollisions: o.avoidCollisions, collisionPadding: o.collisionPadding, collisionBoundary: boundaries(o.collisionBoundary),
      sticky: o.sticky, hideWhenDetached: o.hideWhenDetached, dir: this.select.dirValue, onPlaced: () => this.#placed()
    })
    this.releases.push(() => placement.release())
  }

  #placed() {
    if (this.isPositioned) return
    this.isPositioned = true
    this.viewport.addEventListener("scroll", () => this.#onScroll(), { signal: this.abort.signal })
    // The visibility of the buttons is read first; the focus effect runs before the buttons mount.
    const wanted = this.#wanted()
    this.#focusSelected()
    this.#updateButtons(wanted)
    this.#updateButtons() // the scroll event of the focus would do it a frame later
  }

  // SelectItemAlignedPosition (sel:L536-697): the selected item text sits over the Value and the item middle over the
  // trigger middle. Like Radix it does nothing without a Value node.
  #position() {
    const { element: trigger, valueNode } = this.select
    const { wrapper, content, viewport, selectedItem, selectedText } = this
    if (!(trigger && valueNode && wrapper && content && viewport && selectedItem && selectedText)) return

    const triggerRect = trigger.getBoundingClientRect()
    const contentRect = content.getBoundingClientRect()
    const valueRect = valueNode.getBoundingClientRect()
    const textRect = selectedText.getBoundingClientRect()
    if (this.select.dirValue !== "rtl") {
      const left = valueRect.left - (textRect.left - contentRect.left)
      const minWidth = triggerRect.width + (triggerRect.left - left)
      const width = Math.max(minWidth, contentRect.width)
      const rightEdge = window.innerWidth - CONTENT_MARGIN
      wrapper.style.minWidth = `${minWidth}px`
      wrapper.style.left = `${clamp(left, [CONTENT_MARGIN, Math.max(CONTENT_MARGIN, rightEdge - width)])}px`
    } else {
      const right = window.innerWidth - valueRect.right - (contentRect.right - textRect.right)
      const minWidth = triggerRect.width + (window.innerWidth - triggerRect.right - right)
      const width = Math.max(minWidth, contentRect.width)
      const leftEdge = window.innerWidth - CONTENT_MARGIN
      wrapper.style.minWidth = `${minWidth}px`
      wrapper.style.right = `${clamp(right, [CONTENT_MARGIN, Math.max(CONTENT_MARGIN, leftEdge - width)])}px`
    }

    const items = this.#items()
    const availableHeight = window.innerHeight - CONTENT_MARGIN * 2
    const contentStyles = getComputedStyle(content)
    const borderTop = parseInt(contentStyles.borderTopWidth, 10)
    const paddingTop = parseInt(contentStyles.paddingTop, 10)
    const borderBottom = parseInt(contentStyles.borderBottomWidth, 10)
    const paddingBottom = parseInt(contentStyles.paddingBottom, 10)
    const fullHeight = borderTop + paddingTop + viewport.scrollHeight + paddingBottom + borderBottom
    const minHeight = Math.min(selectedItem.offsetHeight * 5, fullHeight)
    const viewportStyles = getComputedStyle(viewport)
    const viewportPaddingTop = parseInt(viewportStyles.paddingTop, 10)
    const viewportPaddingBottom = parseInt(viewportStyles.paddingBottom, 10)
    const topEdgeToTriggerMiddle = triggerRect.top + triggerRect.height / 2 - CONTENT_MARGIN
    const triggerMiddleToBottomEdge = availableHeight - topEdgeToTriggerMiddle
    const halfItem = selectedItem.offsetHeight / 2
    const contentTopToItemMiddle = borderTop + paddingTop + selectedItem.offsetTop + halfItem
    const itemMiddleToContentBottom = fullHeight - contentTopToItemMiddle

    if (contentTopToItemMiddle <= topEdgeToTriggerMiddle) {
      const isLast = items.length > 0 && selectedItem === items.at(-1)
      wrapper.style.bottom = "0px"
      const viewportOffsetBottom = content.clientHeight - viewport.offsetTop - viewport.offsetHeight
      const clamped = Math.max(triggerMiddleToBottomEdge, halfItem + (isLast ? viewportPaddingBottom : 0) + viewportOffsetBottom + borderBottom)
      wrapper.style.height = `${contentTopToItemMiddle + clamped}px`
    } else {
      const isFirst = items.length > 0 && selectedItem === items[0]
      wrapper.style.top = "0px"
      const clamped = Math.max(topEdgeToTriggerMiddle, borderTop + viewport.offsetTop + (isFirst ? viewportPaddingTop : 0) + halfItem)
      wrapper.style.height = `${clamped + itemMiddleToContentBottom}px`
      viewport.scrollTop = contentTopToItemMiddle - topEdgeToTriggerMiddle + viewport.offsetTop
    }
    wrapper.style.margin = `${CONTENT_MARGIN}px 0`
    wrapper.style.minHeight = `${minHeight}px`
    wrapper.style.maxHeight = `${availableHeight}px`
    this.#placed()
    requestAnimationFrame(() => { this.shouldExpandOnScroll = true })
  }

  // --- viewport and scroll buttons ------------------------------------------------------------------------------------

  // SelectViewport onScroll (sel:L769-792): after placement the wrapper grows with the scrolling, up to the free height.
  #onScroll() {
    const viewport = this.viewport
    if (!this.popper && this.shouldExpandOnScroll) {
      const scrolledBy = Math.abs(this.previousScrollTop - viewport.scrollTop)
      if (scrolledBy > 0) {
        const availableHeight = window.innerHeight - CONTENT_MARGIN * 2
        const previousHeight = Math.max(parseFloat(this.wrapper.style.minHeight), parseFloat(this.wrapper.style.height))
        if (previousHeight < availableHeight) {
          const next = previousHeight + scrolledBy
          const clamped = Math.min(availableHeight, next)
          this.wrapper.style.height = `${clamped}px`
          if (this.wrapper.style.bottom === "0px") {
            viewport.scrollTop = next - clamped > 0 ? next - clamped : 0
            this.wrapper.style.justifyContent = "flex-end"
          }
        }
      }
    }
    this.previousScrollTop = viewport.scrollTop
    this.#updateButtons()
  }

  // A scroll button exists only while the viewport can scroll that way (sel:L976-1039).
  #wanted() {
    const viewport = this.viewport
    return this.buttons.filter(({ kind }) => (kind === "up" ? viewport.scrollTop > 0 : Math.ceil(viewport.scrollTop) < viewport.scrollHeight - viewport.clientHeight))
  }

  #updateButtons(wanted = this.#wanted()) {
    const mounted = []
    this.buttons.forEach((button) => {
      const visible = wanted.includes(button)
      if (visible === button.shown) return
      button.shown = visible
      if (visible) {
        button.marker.after(button.node)
        mounted.push(button)
      } else {
        button.node.remove()
      }
    })
    if (mounted.length === 0) return
    // handleScrollButtonChange (sel:L651-660) runs before the mount effect of the button (sel:L1055-1058).
    if (!this.popper && this.shouldReposition) {
      this.#position()
      this.#focusSelected()
      this.shouldReposition = false
    }
    this.#items().find((item) => item === document.activeElement)?.scrollIntoView({ block: "nearest" })
  }

  #bindButton(node) {
    const direction = node.dataset.slot.includes("-up-") ? -1 : 1
    const on = (type, handler) => node.addEventListener(type, handler, { signal: this.abort.signal })
    const start = () => {
      if (this.scrollTimer !== null) return
      this.scrollTimer = window.setInterval(() => {
        if (this.viewport && this.selectedItem) this.viewport.scrollTop += direction * this.selectedItem.offsetHeight
      }, 50)
    }
    const stop = () => {
      window.clearInterval(this.scrollTimer)
      this.scrollTimer = null
    }
    on("pointerdown", start)
    on("pointermove", () => {
      this.content.focus()
      start()
    })
    on("pointerleave", stop)
  }

  // --- focus and keyboard ----------------------------------------------------------------------------------------------

  #focusSelected() { this.#focusFirst([this.selectedItem, this.content]) }

  #focusFirst(candidates) {
    const items = this.#items()
    const previous = document.activeElement
    for (const candidate of candidates) {
      if (candidate === previous) return
      candidate?.scrollIntoView({ block: "nearest" })
      if (candidate === items[0] && this.viewport) this.viewport.scrollTop = 0
      if (candidate === items.at(-1) && this.viewport) this.viewport.scrollTop = this.viewport.scrollHeight
      candidate?.focus()
      if (document.activeElement !== previous) return
    }
  }

  #search(search) {
    const items = this.#enabled()
    const current = items.find((item) => item === document.activeElement)
    const next = matchItem(items, search, current, textOf)
    if (next) setTimeout(() => next.focus())
  }

  #bind() {
    const on = (type, handler) => this.content.addEventListener(type, handler, { signal: this.abort.signal })
    on("keydown", (event) => this.#onKeyDown(event))
    on("click", (event) => this.#onClick(event))
    on("pointerdown", (event) => this.#itemPointer(event))
    on("pointermove", (event) => this.#onPointerMove(event))
    on("pointerup", (event) => this.#onPointerUp(event))
    on("focusin", (event) => this.#onFocus(event, true))
    on("focusout", (event) => this.#onFocus(event, false))
    on("contextmenu", (event) => event.preventDefault())
    this.#items().forEach((item) => {
      item.addEventListener("pointerleave", () => { if (item === document.activeElement) this.content.focus() }, { signal: this.abort.signal })
    })
  }

  #onKeyDown(event) {
    const item = this.#itemOf(event.target)
    if (item === event.target) this.#itemKeyDown(event, item)
    if (event.defaultPrevented) return

    if (event.key === "Tab") event.preventDefault()
    if (!(event.ctrlKey || event.altKey || event.metaKey) && event.key.length === 1) this.search.push(event.key)
    if (!NAVIGATION_KEYS.includes(event.key)) return

    let candidates = this.#enabled()
    if (["ArrowUp", "End"].includes(event.key)) candidates.reverse()
    if (["ArrowUp", "ArrowDown"].includes(event.key)) candidates = candidates.slice(candidates.indexOf(event.target) + 1)
    setTimeout(() => this.#focusFirst(candidates))
    event.preventDefault()
  }

  #itemKeyDown(event, item) {
    if (isDisabled(item) || (this.search.search !== "" && event.key === " ")) return
    if (SELECTION_KEYS.includes(event.key)) this.#select(item)
    if (event.key === " ") event.preventDefault()
  }

  #select(item) {
    this.select.requestValue(item.getAttribute("data-chadcn--select-value"))
    this.select.requestOpen(false)
  }

  #itemPointer(event) {
    const item = this.#itemOf(event.target)
    if (item) this.pointerTypes.set(item, event.pointerType)
  }

  #pointerType(item) { return this.pointerTypes.get(item) ?? "touch" }

  #onClick(event) {
    const item = this.#itemOf(event.target)
    if (!item || event.defaultPrevented || isDisabled(item)) return
    if (this.#pointerType(item) !== "mouse") this.#select(item)
  }

  #onPointerUp(event) {
    const item = this.#itemOf(event.target)
    if (!item || event.defaultPrevented || isDisabled(item)) return
    if (this.#pointerType(item) === "mouse") this.#select(item)
  }

  #onPointerMove(event) {
    const item = this.#itemOf(event.target)
    if (!item || event.defaultPrevented) return
    this.pointerTypes.set(item, event.pointerType)
    if (isDisabled(item)) this.content.focus()
    else if (event.pointerType === "mouse") item.focus({ preventScroll: true })
  }

  // data-highlighted and aria-selected follow DOM focus (sel:L864-873).
  #onFocus(event, focused) {
    const item = this.#itemOf(event.target)
    if (!item) return
    const selected = item.dataset.state === "checked"
    item.toggleAttribute("data-highlighted", focused)
    item.setAttribute("aria-selected", String(selected && focused))
  }
}

export default class extends Controller {
  static values = {
    open: Boolean,
    controlledOpen: Boolean,
    value: String,
    controlledValue: Boolean,
    disabled: Boolean,
    dir: { type: String, default: "ltr" },
    contentId: String,
    name: String,
    form: String,
    autoComplete: String,
    typeaheadTimeout: { type: Number, default: 1000 }
  }

  connect() {
    this.template = templates.get(this.element) ?? document.querySelector(`template[data-${TEMPLATE}="${this.contentIdValue}"]`)
    if (!this.template) return
    templates.set(this.element, this.template)
    this.template.remove()

    this.abort = new AbortController()
    const { signal } = this.abort
    this.items = registry(this.template)
    this.value = this.valueValue
    this.initialValue = this.value
    this.isOpen = this.openValue
    this.pointerType = "touch"
    this.pointerDownPos = null
    this.disconnecting = false
    this.content = null
    this.valueNode = this.element.querySelector('[data-slot="select-value"]')
    this.search = typeahead({ onSearch: (search) => this.#triggerSearch(search), timeout: this.typeaheadTimeoutValue })

    this.element.addEventListener("click", (event) => this.#onClick(event), { signal })
    this.element.addEventListener("pointerdown", (event) => this.#onPointerDown(event), { signal })
    this.element.addEventListener("keydown", (event) => this.#onKeyDown(event), { signal })
    document.addEventListener("turbo:before-cache", () => this.#reset(), { signal })

    this.#mountBubble()
    this.#syncTrigger()
    if (this.isOpen || this.#forceMounted) this.#mount()
  }

  get #forceMounted() { return JSON.parse(this.template.getAttribute("data-options") || "{}").forceMount === true }

  disconnect() {
    if (!this.template) return
    this.disconnecting = true
    this.content?.teardown()
    this.abort.abort()
    this.search.release()
    this.bubble.release()
    this.template = null
  }

  // A controlled select follows the values the server re-rendered.
  openValueChanged(value) {
    if (this.template && value !== this.isOpen) this.#applyOpen(value)
  }

  valueValueChanged(value) {
    if (this.template && value !== this.value) this.#applyValue(value)
  }

  // useControllableState: the event fires on every change request, the DOM only changes when uncontrolled.
  requestOpen(next) {
    if (next === this.isOpen) return
    this.dispatch("open-change", { detail: { open: next }, cancelable: false })
    if (!this.controlledOpenValue) this.#applyOpen(next)
  }

  requestValue(next) {
    if (next === this.value) return
    this.dispatch("value-change", { detail: { value: next }, cancelable: false })
    if (!this.controlledValueValue) this.#applyValue(next)
  }

  #applyOpen(next) {
    this.isOpen = next
    this.#syncTrigger()
    if (!next) return this.content?.close()
    if (this.content?.options.forceMount) return this.content.reopen()
    this.content?.teardown()
    this.#mount()
  }

  #mount() {
    this.content = new SelectContent(this, this.template, { open: this.isOpen })
    this.content.mount()
  }

  #applyValue(next) {
    this.value = next
    this.#renderValue()
    this.bubble.sync({ value: next })
    this.content?.applySelection()
  }

  #syncTrigger() {
    this.element.setAttribute("aria-expanded", String(this.isOpen))
    this.element.dataset.state = this.isOpen ? "open" : "closed"
    if (this.isOpen) this.element.setAttribute("aria-controls", this.contentIdValue)
    else this.element.removeAttribute("aria-controls")
  }

  // SelectValue (sel:L252-262): the placeholder, its own children, or a copy of the selected item (sel:L959).
  #renderValue() {
    this.element.toggleAttribute("data-placeholder", blank(this.value))
    const node = this.valueNode
    if (!node) return
    const children = node.getAttribute("data-chadcn--select-children")
    if (blank(this.value)) node.textContent = node.getAttribute("data-chadcn--select-placeholder") ?? ""
    else if (children !== null) node.innerHTML = children
    else node.innerHTML = this.items.find((item) => item.value === this.value)?.html ?? ""
  }

  // SelectBubbleInput: the native select that forms submit and that autofill writes to.
  #mountBubble() {
    const hidden = this.element.nextElementSibling
    this.bubble = new FormBubbleInput(this.element, {
      type: "select",
      name: this.nameValue || undefined,
      form: this.formValue || undefined,
      autocomplete: this.autoCompleteValue || undefined,
      value: this.value,
      required: this.element.getAttribute("aria-required") === "true",
      disabled: this.disabledValue,
      options: this.items.map(({ value, label, disabled }) => ({ value, label, disabled })),
      onReset: () => this.requestValue(this.initialValue)
    })
    if (!this.bubble.present) {
      if (hidden?.tagName === "SELECT" && hidden.getAttribute("aria-hidden") === "true") hidden.remove()
      return
    }
    this.bubble.input.addEventListener("change", (event) => {
      if (event.target.value !== (this.value ?? "")) this.requestValue(event.target.value)
    }, { signal: this.abort.signal })
  }

  // A cached page must not restore an open select.
  #reset() {
    this.disconnecting = true
    this.content?.teardown()
    this.disconnecting = false
    this.isOpen = false
    this.#syncTrigger()
    this.element.after(this.template)
  }

  // --- trigger -------------------------------------------------------------------------------------------------------

  #handleOpen(pointerEvent) {
    if (pointerEvent) this.pointerDownPos = { x: Math.round(pointerEvent.pageX), y: Math.round(pointerEvent.pageY) }
    if (this.element.disabled) return
    this.requestOpen(true)
    this.search.reset()
  }

  #onClick(event) {
    if (event.defaultPrevented) return
    this.element.focus()
    if (this.pointerType !== "mouse") this.#handleOpen(event)
  }

  #onPointerDown(event) {
    if (event.defaultPrevented) return
    this.pointerType = event.pointerType
    if (event.target.hasPointerCapture?.(event.pointerId)) event.target.releasePointerCapture(event.pointerId)
    if (event.button === 0 && event.ctrlKey === false && event.pointerType === "mouse") {
      this.#handleOpen(event)
      event.preventDefault()
    }
  }

  #onKeyDown(event) {
    if (event.defaultPrevented) return
    const typingAhead = this.search.search !== ""
    if (!(event.ctrlKey || event.altKey || event.metaKey) && event.key.length === 1) this.search.push(event.key)
    if (typingAhead && event.key === " ") return
    if (OPEN_KEYS.includes(event.key)) {
      this.#handleOpen()
      event.preventDefault()
    }
  }

  // Typeahead on the closed trigger changes the value without opening (sel:L174-181).
  #triggerSearch(search) {
    const enabled = this.items.filter((item) => !item.disabled)
    const current = enabled.find((item) => item.value === this.value)
    const next = matchItem(enabled, search, current, (item) => item.textValue)
    if (next) this.requestValue(next.value)
  }
}
