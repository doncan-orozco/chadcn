// The mounted popup of the Combobox (Base UI 1.9.0 `Combobox.Portal/Positioner/Popup/List`, spec dev/port/specs/combobox.md,
// Behavior): the portal container, the modal backdrop, the open/closed/side/empty attributes, the live region, the dismiss buttons,
// the focus guards of a popup with its own search field, the layers that only an open popup holds, and the list, filtered by
// detaching and re-attaching its server-rendered item nodes. No Stimulus: the chadcn--combobox controller creates one
// `ComboboxPopup` per opening, drives it and tears it down; the citations (`popup:L`, `ffm:L`, `live:L`) are the spec's.
//
// Known divergences: none beyond the controller's (the modal popup traps no focus).
import { anchorPositioner } from "chadcn/primitives/anchor_positioner"
import { dismissable } from "chadcn/primitives/dismissable_layer"
import { hideOthers } from "chadcn/primitives/hide_others"
import { generateId } from "chadcn/primitives/ids"
import { presence } from "chadcn/primitives/presence"
import { scrollLock } from "chadcn/primitives/scroll_lock"
import { mountTemplate } from "chadcn/primitives/template_mount"

/** Attribute naming the combobox part of an element. @type {string} */
export const PART = "data-chadcn--combobox-part"
/** Attribute holding the form value of an item. @type {string} */
export const KEY = "data-chadcn--combobox-key"
/**
 * CSS selector of a combobox part.
 * @param {string} name
 * @returns {string}
 * @example
 * host.querySelector(part("input"))
 */
export const part = (name) => `[${PART}="${name}"]`
/** Inline style of Base UI's visually hidden elements (the dismiss buttons). @type {string} */
export const VISUALLY_HIDDEN = "clip-path: inset(50%); overflow: hidden; white-space: nowrap; border: 0px; padding: 0px; width: 1px; height: 1px; margin: -1px; position: absolute;"
const VISUALLY_HIDDEN_FIXED = "clip-path: inset(50%); overflow: hidden; white-space: nowrap; border: 0px; padding: 0px; width: 1px; height: 1px; margin: 0px; position: fixed; top: 0px; left: 0px;"
const LIVE_MARKER = "⁠"
const LIVE_RESET_MS = 200

/**
 * A visually hidden `role=button` span (Base UI's DismissButton, input:L341-343, popup:L113-115).
 * @param {string} partName The combobox part it plays (`dismiss-start`, `dismiss-end`).
 * @param {string} label Its accessible name.
 * @returns {HTMLSpanElement}
 * @example
 * input.before(dismissButton("dismiss-start", "Dismiss"))
 */
export function dismissButton(partName, label) {
  const span = document.createElement("span")
  span.setAttribute("role", "button")
  span.setAttribute("aria-label", label)
  span.setAttribute("style", VISUALLY_HIDDEN)
  span.setAttribute(PART, partName)
  return span
}

/**
 * The dismiss button before an input outside the popup, present while the popup is open (input:L341-343).
 * @param {HTMLElement} host The element of the chadcn--combobox controller.
 * @param {Element|null} control The input outside the popup (null: a search field inside the popup, no button).
 * @param {boolean} open
 * @param {string} label Accessible name of the button.
 * @example
 * syncDismissStart(host, input, true, "Dismiss")
 */
export function syncDismissStart(host, control, open, label) {
  const existing = host.querySelector(part("dismiss-start"))
  if (!open || !control) return existing?.remove()
  if (!existing) control.before(dismissButton("dismiss-start", label))
}

/**
 * State attributes of the controls that stay in the document (the input and the trigger) and of a search field in the popup:
 * aria-expanded / aria-controls, data-popup-open / data-pressed, data-list-empty, data-popup-side, the trigger's data-placeholder.
 * @param {object} state
 * @param {Element|null} state.control The input outside the popup.
 * @param {Element|null} state.trigger
 * @param {ComboboxPopup|null} state.popup The mounted popup.
 * @param {boolean} state.open
 * @param {boolean} state.empty Nothing matches.
 * @param {boolean} state.placeholder Nothing is selected.
 * @param {boolean} state.inPopup The search field lives inside the popup (the trigger then controls the popup).
 * @param {string} state.id Prefix of the ids the server rendered (`<id>-list`, `<id>-popup`).
 * @example
 * markControls({ control: input, trigger: null, popup: null, open: false, empty: false, placeholder: true, inPopup: false, id: "fruit" })
 */
export function markControls({ control, trigger, popup, open, empty, placeholder, inPopup, id }) {
  const side = popup?.side ?? null
  for (const el of [control, trigger]) {
    if (!el) continue
    const controls = el === trigger && inPopup ? (popup?.popup.id || `${id}-popup`) : (popup?.list.id || `${id}-list`)
    el.setAttribute("aria-expanded", String(open))
    el.toggleAttribute("data-popup-open", open)
    el.toggleAttribute("data-pressed", open)
    el.toggleAttribute("data-list-empty", empty)
    if (side) el.setAttribute("data-popup-side", side)
    else el.removeAttribute("data-popup-side")
    if (open) el.setAttribute("aria-controls", controls)
    else el.removeAttribute("aria-controls")
    if (el === trigger) el.toggleAttribute("data-placeholder", placeholder)
    else if (!open) el.removeAttribute("aria-activedescendant")
  }
  if (popup?.input) {
    popup.input.toggleAttribute("data-list-empty", empty)
    if (side) popup.input.setAttribute("data-popup-side", side)
    else popup.input.removeAttribute("data-popup-side")
  }
}

/**
 * One mounted popup: created when the combobox opens, torn down when its exit ends (or at once on disconnect).
 * @example
 * const popup = new ComboboxPopup(template, { side: "bottom", align: "start", empty: false, modal: false, inPopup: false })
 * popup.renderList(new Set(["apple"]), null, "fruit")
 * popup.teardown()
 */
export class ComboboxPopup {
  /**
   * Mounts the template into `body > div[data-base-ui-portal]` and marks the positioner and popup open.
   * @param {HTMLTemplateElement} template The inert `<template>` the server rendered the popup into.
   * @param {object} options
   * @param {string} [options.side="bottom"] Side before the first placement.
   * @param {string} [options.align="start"] Alignment before the first placement.
   * @param {boolean} options.empty Whether the list has no match (data-empty, the Empty part).
   * @param {boolean} options.modal Adds the backdrop and the scroll lock.
   * @param {boolean} options.inPopup The search field lives inside the popup.
   * @param {Element|null} [options.cutout] The control the backdrop leaves pressable.
   */
  constructor(template, { side, align, empty, modal, inPopup, cutout = null }) {
    this.modal = modal
    this.inPopup = inPopup
    this.releases = []
    this.openReleases = []
    this.listeners = new AbortController()
    this.presence = null
    this.focusFrame = 0
    this.tornDown = false
    this.container = document.createElement("div")
    this.container.setAttribute("data-base-ui-portal", "")
    this.container.id = generateId("combobox-portal")
    document.body.append(this.container)
    try {
      if (modal) this.backdrop = this.#backdrop(cutout)
      this.mount = mountTemplate(template, { into: this.container })
      this.positioner = this.mount.nodes[0]
      this.popup = this.positioner?.querySelector(part("popup"))
      if (!this.popup) throw new Error("chadcn--combobox: the content template renders no positioner with a popup part")
      this.list = this.positioner.querySelector(part("list"))
      this.input = this.positioner.querySelector(part("input"))
      this.empty = this.positioner.querySelector(part("empty"))
      this.emptyNodes = this.empty ? [...this.empty.childNodes] : []
      this.#collect()
      this.#markMounted(side ?? "bottom", align ?? "start", empty)
    } catch (error) {
      cancelAnimationFrame(this.startFrame)
      this.mount?.unmount()
      this.container.remove()
      throw error
    }
  }

  /**
   * Keeps the popup mounted through its exit animation; `onExited` runs when it ends. A previous tracking is released.
   * @param {() => void} onExited
   */
  trackPresence(onExited) {
    this.presence?.release()
    this.presence = presence(this.popup, { onExited })
  }

  #backdrop(cutoutEl) {
    const el = document.createElement("div")
    el.setAttribute("role", "presentation")
    el.setAttribute("data-base-ui-inert", "")
    el.setAttribute("aria-hidden", "true")
    const cutout = cutoutEl?.getBoundingClientRect()
    const clip = cutout
      ? `polygon(0% 0%, 100% 0%, 100% 100%, 0% 100%, 0% 0%, ${cutout.left}px ${cutout.top}px, ${cutout.left}px ${cutout.bottom}px, ${cutout.right}px ${cutout.bottom}px, ${cutout.right}px ${cutout.top}px, ${cutout.left}px ${cutout.top}px)`
      : ""
    el.style.cssText = `position: fixed; inset: 0px; user-select: none; clip-path: ${clip};`
    this.container.append(el)
    return el
  }

  // The item records (node, form value, disabled, group) and the original children of the list and of each group.
  #collect() {
    this.records = new Map()
    this.sources = new Map()
    const groups = [...this.positioner.querySelectorAll(part("group"))]
    for (const container of [this.list, ...groups]) if (container) this.sources.set(container, [...container.children])
    for (const el of this.positioner.querySelectorAll(part("item"))) {
      this.records.set(el, { el, key: el.getAttribute(KEY), disabled: el.hasAttribute("data-disabled"), group: el.closest(part("group")) })
    }
    this.shown = [...this.records.keys()]
  }

  // Data attributes of the mounted positioner and popup (open, side, align, empty).
  #markMounted(side, align, empty) {
    this.side = side
    for (const el of [this.positioner, this.popup]) {
      el.setAttribute("data-open", "")
      el.setAttribute("data-side", side)
      el.setAttribute("data-align", align)
    }
    this.popup.setAttribute("data-base-ui-focusable", "")
    // Base UI mounts with `transition: none` for one frame, so the transform origin set by the first placement does not animate.
    this.popup.setAttribute("data-starting-style", "")
    this.popup.style.transition = "none"
    this.startFrame = requestAnimationFrame(() => {
      this.popup.removeAttribute("data-starting-style")
      this.popup.style.removeProperty("transition")
      if (!this.popup.getAttribute("style")) this.popup.removeAttribute("style")
    })
    this.syncEmpty(empty)
  }

  /**
   * data-empty on the positioner, popup and list; the Empty part holds its children only while nothing matches.
   * @param {boolean} empty
   */
  syncEmpty(empty) {
    for (const el of [this.positioner, this.popup, this.list]) el?.toggleAttribute("data-empty", empty)
    if (!this.empty) return
    if (empty && !this.empty.childNodes.length) this.empty.append(...this.emptyNodes)
    else if (!empty) this.emptyNodes.forEach((node) => node.remove())
  }

  /**
   * The first mount with an empty list announces the Empty text with a word joiner for 200 ms (live:L8-58).
   * @param {boolean} empty
   */
  announce(empty) {
    if (!this.empty || !empty) return
    const walker = document.createTreeWalker(this.empty, NodeFilter.SHOW_TEXT)
    let last = null
    while (walker.nextNode()) if (walker.currentNode.nodeValue !== "") last = walker.currentNode
    if (!last) return
    const original = last.data
    const marked = original + LIVE_MARKER
    last.nodeValue = marked
    const timer = setTimeout(() => { if (last.nodeValue === marked) last.nodeValue = original }, LIVE_RESET_MS)
    this.releases.push(() => { clearTimeout(timer); if (last.nodeValue === marked) last.nodeValue = original })
  }

  /**
   * A search field in the popup shows `text`; with `focus` it takes the focus on the next frame, after the press that opened the
   * popup has run its default action (a mouse press focuses the trigger first, then focus moves in).
   * @param {string} text
   * @param {boolean} focus
   */
  seedInput(text, focus) {
    if (!this.inPopup || !this.input) return
    this.input.value = text
    this.input.setAttribute("value", text)
    if (!focus) return
    cancelAnimationFrame(this.focusFrame)
    this.focusFrame = requestAnimationFrame(() => this.input.focus({ preventScroll: true }))
  }

  /**
   * Anchors the positioner (lazy flip) and keeps side, align and anchor-hidden on the popup.
   * @param {Element|null} anchor
   * @param {object} options `side`, `sideOffset`, `align`, `alignOffset` and `dir` of anchorPositioner.
   * @param {(side: string) => void} onSide Runs after each placement with the side it settled on.
   */
  place(anchor, options, onSide) {
    if (!anchor) return
    this.placement = anchorPositioner(anchor, this.positioner, {
      ...options,
      lazyFlip: true,
      onPlace: ({ side, align, anchorHidden }) => {
        this.side = side
        this.popup.setAttribute("data-side", side)
        this.popup.setAttribute("data-align", align)
        this.popup.toggleAttribute("data-anchor-hidden", anchorHidden)
        onSide(side)
      }
    })
    this.releases.push(() => this.placement.release())
  }

  /**
   * The dismiss button after the popup, a keyboard way to close it (popup:L113-115); a non-modal search popup has none.
   * @param {string} label Accessible name of the button.
   * @param {(event: Event) => void} onPress
   */
  addDismissEnd(label, onPress) {
    if (this.inPopup && !this.modal) return
    const end = dismissButton("dismiss-end", label)
    end.addEventListener("click", onPress, { signal: this.listeners.signal })
    this.positioner.append(end)
  }

  /**
   * Popup with its own search field (FloatingPortal + non-modal focus manager): sentinels around the trigger and the popup.
   * Tabbing onto an outside one moves focus into the popup; an inside one runs `onLeave`.
   * @param {Element|null} trigger
   * @param {(event: FocusEvent) => void} onLeave
   */
  addFocusGuards(trigger, onLeave) {
    if (!this.inPopup || !trigger) return
    const { signal } = this.listeners
    const guard = (type, handler) => {
      const span = document.createElement("span")
      span.setAttribute("data-type", type)
      span.setAttribute("aria-hidden", "true")
      span.tabIndex = 0
      span.setAttribute("data-base-ui-focus-guard", "")
      span.setAttribute("style", VISUALLY_HIDDEN_FIXED)
      span.addEventListener("focus", handler, { signal })
      return span
    }
    const enter = () => this.input?.focus({ preventScroll: true })
    const owns = document.createElement("span")
    owns.setAttribute("aria-owns", this.container.id)
    owns.setAttribute("style", "clip-path: inset(50%); position: fixed; top: 0px; left: 0px;")
    const outside = [guard("outside", enter), owns, guard("outside", enter)]
    trigger.after(...outside)
    this.releases.push(() => outside.forEach((el) => el.remove()))
    this.positioner.prepend(guard("inside", onLeave))
    this.positioner.append(guard("inside", onLeave))
  }

  /**
   * What only an open popup holds: outside press and Escape (dismissable layer), aria-hidden / inert on the page, the modal
   * scroll lock. They end when the close starts, not when the exit animation does (ffm:L335-354).
   * @param {object} options
   * @param {() => Element[]} options.branches Elements outside the popup whose presses are not outside presses.
   * @param {Element[]} options.keep Elements `aria-hidden` spares besides the portal.
   * @param {boolean} options.ariaHidden Whether the page gets `aria-hidden` (an input outside the popup, or a modal popup).
   * @param {(reason: string, event: Event|null) => void} options.onDismiss
   */
  openLayers({ branches, keep, ariaHidden, onDismiss }) {
    let dismiss = null
    this.openReleases.push(dismissable(this.popup, {
      branches,
      onEscape: (event) => { dismiss = { reason: "escape-key", event } },
      onPointerDownOutside: (event) => { dismiss = { reason: "outside-press", event: event.detail.originalEvent } },
      onFocusOutside: (event) => event.preventDefault(),
      onDismiss: () => onDismiss(dismiss?.reason ?? "none", dismiss?.event ?? null)
    }))
    this.openReleases.push(this.#hideOutside(keep, ariaHidden))
    if (this.modal) this.openReleases.push(scrollLock())
  }

  // aria-hidden on everything but the portal and `keep`; `data-base-ui-inert` on the outermost body children that are not the portal.
  #hideOutside(keep, ariaHidden) {
    // Base UI marks with `aria-hidden` only, not with the primitive's own `data-aria-hidden` marker.
    const release = ariaHidden ? hideOthers([this.container, ...keep], document.body, { marker: false }) : () => {}
    const marked = [...document.body.children].filter((child) => child !== this.container && child.tagName !== "SCRIPT" && !child.hasAttribute("data-base-ui-inert"))
    marked.forEach((el) => el.setAttribute("data-base-ui-inert", ""))
    return () => {
      release()
      marked.forEach((el) => el.removeAttribute("data-base-ui-inert"))
    }
  }

  /** A reopen during the exit: presence enters again, open attributes and pointer events come back. */
  markOpen() {
    this.presence?.enter()
    for (const el of [this.positioner, this.popup]) {
      el.removeAttribute("data-closed")
      el.setAttribute("data-open", "")
    }
    this.popup.removeAttribute("data-ending-style")
    this.positioner.style.removeProperty("pointer-events")
  }

  /**
   * The close starts: open layers released, closed and ending-style attributes, no pointer events, presence exit.
   * @param {boolean} empty
   */
  markClosed(empty) {
    this.#releaseOpenLayers()
    for (const el of [this.positioner, this.popup]) {
      el.removeAttribute("data-open")
      el.setAttribute("data-closed", "")
    }
    this.popup.setAttribute("data-ending-style", "")
    this.positioner.style.pointerEvents = "none"
    this.syncEmpty(empty)
    this.presence?.exit()
  }

  #releaseOpenLayers() {
    this.openReleases.splice(0).reverse().forEach((release) => release())
  }

  /** Releases everything the popup holds and removes it from the document. */
  teardown() {
    if (this.tornDown) return
    this.tornDown = true
    this.listeners.abort()
    cancelAnimationFrame(this.startFrame)
    cancelAnimationFrame(this.focusFrame)
    this.presence?.release()
    this.#releaseOpenLayers()
    this.releases.splice(0).reverse().forEach((release) => release())
    this.mount.unmount()
    this.backdrop?.remove()
    this.container.remove()
  }

  /**
   * Detaches the items that do not match and re-attaches the ones that do, best fuzzy score first (spec, Filtering); a group
   * without a visible item leaves too. Shown items get the ids `<idPrefix>-<index>` in display order.
   * @param {Set<string>|null} visible Form values to show (null: every item).
   * @param {Map<string, number>|null} scores Fuzzy score per form value (null: source order).
   * @param {string} idPrefix
   * @returns {boolean} false when the popup has no list.
   */
  renderList(visible, scores, idPrefix) {
    if (!this.list) return false
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
    this.shown = [...this.list.querySelectorAll(part("item"))]
    this.shown.forEach((el, index) => { el.id = `${idPrefix}-${index}` })
    return true
  }

  /**
   * aria-selected / data-selected and the item indicator (cloned from the list's indicator template) of every item.
   * @param {string[]} selected Form values of the selection.
   */
  renderItemStates(selected) {
    const template = this.list?.querySelector(part("indicator-template"))
    for (const { el, key } of this.records.values()) {
      const isSelected = selected.includes(key)
      el.setAttribute("aria-selected", String(isSelected))
      el.toggleAttribute("data-selected", isSelected)
      const indicator = el.querySelector("[data-slot=combobox-item-indicator]")
      if (isSelected && !indicator && template) el.append(template.content.cloneNode(true))
      if (!isSelected) indicator?.remove()
    }
  }

  /**
   * data-highlighted on the shown item at `active`, aria-activedescendant on `owners`.
   * @param {number} active Index in `shown`, -1 for none.
   * @param {Element[]} owners Elements that point at the highlighted item.
   */
  paintActive(active, owners) {
    this.shown.forEach((el, index) => el.toggleAttribute("data-highlighted", index === active))
    const id = active >= 0 ? this.shown[active]?.id : null
    for (const el of owners) id ? el.setAttribute("aria-activedescendant", id) : el.removeAttribute("aria-activedescendant")
  }
}
