import { Controller } from "@hotwired/stimulus"
import { generateId } from "chadcn/primitives/ids"
import { scoreItem } from "chadcn/primitives/scorer"
import { mountTemplate } from "chadcn/primitives/template_mount"

// shadcn Command: a hand-written equivalent of cmdk 1.1.1 (no third-party JavaScript). Spec: dev/port/specs/command.md
// (Behavior); the `cmdk:<n>` citations point at the minified cmdk source the spec cites. The server renders every item;
// the controller keeps cmdk's state (search, selected value, scores) and mounts/unmounts nodes the way React does:
// detached nodes are kept here and re-inserted before the next already-mounted sibling of their SOURCE order.
//
// Events (prefix chadcn--command:): `value-change` (controlled root), `search-change` (the input), `select` (an item).
// A custom filter is assigned from JavaScript: `controller.filter = (value, search, keywords) => number`.
// Known divergences: the default scorer is scorer.js, not command-score; aria-activedescendant follows a controlled
// value immediately (spec Deviations 5).

const GROUP = '[cmdk-group=""]'
const GROUP_ITEMS = '[cmdk-group-items=""]'
const HEADING = '[cmdk-group-heading=""]'
const ITEM = '[cmdk-item=""]'
const ENABLED_ITEM = `${ITEM}:not([aria-disabled="true"])`
const SEPARATOR = '[cmdk-separator=""]'
const KEYWORDS = "data-chadcn--command-keywords"
const FORCE_MOUNT = "data-chadcn--command-force-mount"
const ALWAYS_RENDER = "data-chadcn--command-always-render"
const SEARCH = "data-chadcn--command-search"

const defaultFilter = (value, search, keywords) => scoreItem(search, value, keywords)

export default class extends Controller {
  static values = {
    value: String,
    controlled: Boolean,
    shouldFilter: { type: Boolean, default: true },
    loop: Boolean,
    vimBindings: { type: Boolean, default: true },
    disablePointerSelection: Boolean,
  }
  static targets = ["empty"]

  connect() {
    this.list = this.element.querySelector('[cmdk-list=""]')
    this.sizer = this.element.querySelector('[cmdk-list-sizer=""]')
    this.input = this.element.querySelector('[cmdk-input=""]')
    if (!this.list || !this.sizer) return

    this.search = ""
    this.current = this.valueValue || ""
    this.count = 0
    this.nodes = new Map() // element -> record of an item or separator
    this.groups = new Map() // group element -> { el, forceMount }
    this.sources = new Map() // parent -> its children in source order
    this.empties = new Map() // <template> -> mount
    this.abort = new AbortController()
    const { signal } = this.abort

    this.element.addEventListener("keydown", (event) => this.keydown(event), { signal })
    this.element.addEventListener("input", (event) => this.typed(event), { signal })
    this.element.addEventListener("click", (event) => this.clicked(event), { signal })
    this.element.addEventListener("pointermove", (event) => this.pointerMoved(event), { signal })
    document.addEventListener("turbo:before-cache", () => this.reset(), { signal })

    this.element.querySelectorAll(GROUP).forEach((group) => this.registerGroup(group))
    this.list.querySelectorAll(`${ITEM}, ${SEPARATOR}`).forEach((el) => this.registerNode(el))
    this.observeList()
    this.score()
    if (this.input?.hasAttribute(SEARCH)) this.setSearch(this.input.getAttribute(SEARCH))
    else this.update()
    if (!this.current) this.selectFirst()
    this.renderSelection()
    this.ready = true
  }

  disconnect() {
    this.ready = false
    if (!this.abort) return
    this.reset() // puts back the items this controller detached, so a reconnect registers the full server list
    this.abort.abort()
    this.mutations.disconnect()
    this.resize.disconnect()
    cancelAnimationFrame(this.frame)
    this.abort = null
  }

  // Controlled root: the caller feeds a new selected value back through the value attribute (cmdk:13-18).
  valueValueChanged(value) {
    if (!this.ready || !this.controlledValue) return
    const next = value.trim()
    if (next === this.current) return
    this.current = next
    this.renderSelection()
    this.syncActiveDescendant(this.selectedItem?.id)
  }

  // --- registration --------------------------------------------------------------------------------------------------

  registerGroup(el) {
    if (!el.hasAttribute("data-value")) el.setAttribute("data-value", el.querySelector(HEADING)?.textContent.trim() ?? "undefined")
    this.groups.set(el, { el, parent: el.parentElement, forceMount: el.hasAttribute(FORCE_MOUNT) })
  }

  registerNode(el) {
    const parent = el.parentElement
    if (!this.sources.has(parent)) this.sources.set(parent, [...parent.children])
    const record = { el, parent, mounted: true }
    if (el.matches(SEPARATOR)) {
      record.kind = "separator"
      record.alwaysRender = el.hasAttribute(ALWAYS_RENDER)
    } else {
      const group = el.closest(GROUP)
      if (!el.id) el.id = generateId("command-item")
      if (!el.hasAttribute("data-value")) el.setAttribute("data-value", el.textContent.trim())
      Object.assign(record, {
        kind: "item",
        group,
        disabled: el.getAttribute("aria-disabled") === "true",
        value: el.getAttribute("data-value"),
        keywords: JSON.parse(el.getAttribute(KEYWORDS) || "[]"),
        forceMount: el.hasAttribute(FORCE_MOUNT) || (group?.hasAttribute(FORCE_MOUNT) ?? false),
      })
      // A force-mounted item keeps the score of its registration (cmdk:45, 100-103 only rescore registered items).
      record.score = this.runFilter(record)
    }
    this.nodes.set(el, record)
  }

  get items() {
    return [...this.nodes.values()].filter((record) => record.kind === "item")
  }

  get registered() {
    return this.items.filter((record) => !record.forceMount)
  }

  // Items and groups added later (Turbo Stream) register like cmdk's mount effects; removed ones unregister.
  observeList() {
    this.mutations = new MutationObserver((mutations) => this.mutated(mutations))
    this.mutations.observe(this.element, { childList: true, subtree: true, attributes: true, attributeFilter: [SEARCH] })
    this.resize = new ResizeObserver(() => {
      this.frame = requestAnimationFrame(() => this.list.style.setProperty("--cmdk-list-height", `${this.sizer.offsetHeight.toFixed(1)}px`))
    })
    this.resize.observe(this.sizer)
  }

  mutated(mutations) {
    let changed = false
    for (const mutation of mutations) {
      if (mutation.type === "attributes") {
        const next = mutation.target.getAttribute(SEARCH)
        if (next !== null && next !== this.search) this.setSearch(next, { writeInput: true })
        continue
      }
      mutation.addedNodes.forEach((node) => { if (node.nodeType === Node.ELEMENT_NODE) changed = this.adopt(node) || changed })
      mutation.removedNodes.forEach((node) => { if (node.nodeType === Node.ELEMENT_NODE) changed = this.forget(node) || changed })
    }
    if (!changed) return
    this.score()
    this.sort()
    this.update()
    this.renderSelection()
    if (!this.current || this.lostSelection) this.selectFirst()
    this.lostSelection = false
  }

  adopt(node) {
    if (!this.list.contains(node)) return false
    const found = [node, ...node.querySelectorAll(`${GROUP}, ${ITEM}, ${SEPARATOR}`)]
    let adopted = false
    for (const el of found) {
      if (el.matches(GROUP) && !this.groups.has(el)) {
        this.registerGroup(el)
        if (this.sources.has(el.parentElement)) this.rememberSource(el)
      }
      if (el.matches(`${ITEM}, ${SEPARATOR}`) && !this.nodes.has(el)) {
        this.registerNode(el)
        this.rememberSource(el)
        adopted = true
      }
    }
    return adopted
  }

  // A node the controller detached itself is still mounted=false; anything else that left the document is gone for good.
  // A node that is connected again was moved, not removed.
  forget(node) {
    if (node.isConnected) return false
    let forgotten = false
    const removedGroups = new Set()
    const dropped = new Map() // parent -> Set of removed children
    const drop = (el, parent) => {
      if (!dropped.has(parent)) dropped.set(parent, new Set())
      dropped.get(parent).add(el)
    }
    for (const el of [node, ...node.querySelectorAll(`${GROUP}, ${ITEM}, ${SEPARATOR}`)]) {
      const record = this.nodes.get(el)
      if (record?.mounted) {
        if (el.getAttribute("aria-selected") === "true") this.lostSelection = true
        this.nodes.delete(el)
        drop(el, record.parent)
        forgotten = true
      }
      const group = this.groups.get(el)
      if (group) {
        this.groups.delete(el)
        removedGroups.add(el)
        drop(el, group.parent)
      }
    }
    // Records the filter had detached (separators, items) inside the removed subtree are gone with it.
    for (const [el, record] of this.nodes) {
      if (record.mounted || !(node.contains(record.parent) || removedGroups.has(record.group))) continue
      this.nodes.delete(el)
      forgotten = true
    }
    this.dropSources(node, dropped)
    return forgotten
  }

  // Removes the containers inside a removed node from the source orders, and its removed children from their parents' orders.
  dropSources(node, dropped) {
    for (const parent of [...this.sources.keys()]) if (node.contains(parent)) this.sources.delete(parent)
    dropped.forEach((els, parent) => {
      const order = this.sources.get(parent)
      if (order) this.sources.set(parent, order.filter((el) => !els.has(el)))
    })
  }

  // Keeps the source order of a parent in step with a node added after connect: right after its previous sibling.
  rememberSource(el) {
    const order = this.sources.get(el.parentElement)
    if (order.includes(el)) return
    const previous = order.indexOf(el.previousElementSibling)
    order.splice(previous + 1, 0, el)
  }

  // --- filter, sort, mount (cmdk:92-109, 64-87, 189-211, 237) ----------------------------------------------------------

  get filtering() {
    return this.shouldFilterValue && this.search !== ""
  }

  runFilter(record) {
    if (!record.value) return 0
    return (this.filter ?? defaultFilter)(record.value, this.search, record.keywords)
  }

  score() {
    if (!this.filtering) {
      this.count = this.registered.length
      return
    }
    this.matching = new Set()
    let count = 0
    for (const record of this.registered) {
      record.score = this.runFilter(record)
      if (record.score <= 0) continue
      count += 1
      if (record.group) this.matching.add(record.group)
    }
    this.count = count
  }

  // Stable sort of the currently mounted enabled items by score, each appended to its container. Groups are NOT reordered:
  // cmdk looks them up by an id that never matches their data-value (spec, Search change 2).
  sort() {
    if (!this.filtering) return
    const records = this.enabledItems.map((el) => this.nodes.get(el)).filter(Boolean)
    const ranked = records.map((record, index) => ({ record, index })).sort((a, b) => (b.record.score ?? 0) - (a.record.score ?? 0) || a.index - b.index)
    for (const { record } of ranked) {
      const container = record.el.closest(GROUP_ITEMS) ?? this.sizer
      let node = record.el
      while (node.parentElement && node.parentElement !== container) node = node.parentElement
      container.appendChild(node.parentElement === container ? node : record.el)
    }
  }

  update() {
    const searching = this.search !== ""
    const present = (record) => record.kind === "separator" ? record.alwaysRender || !searching : record.forceMount || !this.filtering || record.score > 0
    const leaving = []
    const entering = []
    for (const record of this.nodes.values()) {
      const wanted = present(record)
      if (!wanted && record.mounted) leaving.push(record)
      else if (wanted && !record.mounted) entering.push(record)
    }
    leaving.forEach((record) => { record.el.remove(); record.mounted = false })
    this.insert(entering)

    for (const { el, forceMount } of this.groups.values()) {
      const shown = forceMount || !this.filtering || this.matching.has(el)
      el.toggleAttribute("hidden", !shown)
    }
    this.emptyTargets.forEach((template) => this.syncEmpty(template))
  }

  // React's host-sibling rule: before the next already-mounted node of the SOURCE order in the same parent, else appended.
  // Walking each source order backwards keeps the next mounted sibling at hand (linear).
  insert(records) {
    const entering = new Map() // parent -> Set of records to mount
    for (const record of records) {
      if (!this.sources.has(record.parent)) {
        this.nodes.delete(record.el)
        continue
      }
      if (!entering.has(record.parent)) entering.set(record.parent, new Set())
      entering.get(record.parent).add(record.el)
    }
    entering.forEach((els, parent) => {
      let next = null
      const siblings = this.sources.get(parent)
      for (let index = siblings.length - 1; index >= 0; index -= 1) {
        const el = siblings[index]
        if (els.has(el)) {
          parent.insertBefore(el, next)
          this.nodes.get(el).mounted = true
          next = el
        } else if (el.parentNode === parent) next = el
      }
    })
  }

  syncEmpty(template) {
    const mount = this.empties.get(template)
    if (this.count === 0 && !mount) this.empties.set(template, mountTemplate(template, { into: "after" }))
    else if (this.count !== 0 && mount) {
      mount.unmount()
      this.empties.delete(template)
    }
  }

  // --- search --------------------------------------------------------------------------------------------------------

  typed(event) {
    const input = event.target
    if (!input.matches?.('[cmdk-input=""]')) return
    this.dispatch("search-change", { target: input, detail: { value: input.value }, cancelable: false })
    if (input.hasAttribute(SEARCH)) input.value = input.getAttribute(SEARCH) // controlled: React restores the value
    else this.setSearch(input.value)
  }

  setSearch(search, { writeInput = false } = {}) {
    if (this.input) {
      if (writeInput) this.input.value = search
      this.input.setAttribute("value", search)
    }
    if (search === this.search) return
    this.search = search
    this.score()
    this.sort()
    this.update()
    this.selectFirst()
  }

  // --- selection (cmdk:25-38, 48-49) -----------------------------------------------------------------------------------

  get enabledItems() {
    return [...this.list.querySelectorAll(ENABLED_ITEM)]
  }

  get selectedItem() {
    return this.list.querySelector(`${ITEM}[aria-selected="true"]`)
  }

  selectFirst() {
    this.setValue(this.enabledItems[0]?.getAttribute("data-value") || undefined, { deferred: true })
  }

  // `deferred`: the selection comes from cmdk's post-render callbacks (mount, search change, removal), where cmdk reads the
  // selected item BEFORE it re-renders: aria-activedescendant names, and the scroll follows, the PREVIOUS selection (none at
  // mount; cmdk:30-32, 19).
  setValue(next, { silent = false, deferred = false } = {}) {
    if (Object.is(this.current, next)) return
    this.current = next
    const active = document.activeElement
    if (this.element.contains(active) && (active.hasAttribute("cmdk-input") || active.hasAttribute("cmdk-root"))) (this.input ?? this.list).focus()
    const previous = this.selectedItem
    this.renderSelection()
    const shown = deferred ? previous : this.selectedItem
    this.syncActiveDescendant(shown?.id)
    if (!silent) this.scrollIntoList(shown)
    if (this.controlledValue) this.dispatch("value-change", { detail: { value: next ?? "" }, cancelable: false })
  }

  renderSelection() {
    for (const record of this.items) {
      const selected = String(!!this.current && this.current === record.value)
      record.el.setAttribute("aria-selected", selected)
      record.el.setAttribute("data-selected", selected)
    }
  }

  syncActiveDescendant(id) {
    for (const el of [this.input, this.list]) {
      if (!el) continue
      if (id) el.setAttribute("aria-activedescendant", id)
      else el.removeAttribute("aria-activedescendant")
    }
  }

  scrollIntoList(item) {
    if (!item) return
    if (item.parentElement?.firstChild === item) item.closest(GROUP)?.querySelector(HEADING)?.scrollIntoView({ block: "nearest" })
    item.scrollIntoView({ block: "nearest" })
  }

  selectItem(item) {
    const value = this.nodes.get(item).value
    this.setValue(value, { silent: true })
    this.dispatch("select", { target: item, detail: { value }, cancelable: false })
  }

  // --- pointer and keyboard --------------------------------------------------------------------------------------------

  itemOf(event) {
    const item = event.target.closest?.(ITEM)
    const record = item && this.nodes.get(item)
    return record && !record.disabled ? item : null
  }

  clicked(event) {
    const item = this.itemOf(event)
    if (item) this.selectItem(item)
  }

  pointerMoved(event) {
    if (this.disablePointerSelectionValue) return
    const item = this.itemOf(event)
    if (item) this.setValue(this.nodes.get(item).value, { silent: true })
  }

  keydown(event) {
    if (event.defaultPrevented || event.isComposing || event.keyCode === 229) return
    switch (event.key) {
      case "n":
      case "j":
        if (this.vimBindingsValue && event.ctrlKey) this.down(event)
        break
      case "ArrowDown":
        this.down(event)
        break
      case "p":
      case "k":
        if (this.vimBindingsValue && event.ctrlKey) this.up(event)
        break
      case "ArrowUp":
        this.up(event)
        break
      case "Home":
        event.preventDefault()
        this.goTo(0)
        break
      case "End":
        event.preventDefault()
        this.goTo(-1)
        break
      case "Enter": {
        event.preventDefault()
        const item = this.selectedItem
        if (item && this.itemOf({ target: item })) this.selectItem(item)
        break
      }
    }
  }

  down(event) {
    event.preventDefault()
    if (event.metaKey) this.goTo(-1)
    else if (event.altKey) this.moveGroup(1)
    else this.move(1)
  }

  up(event) {
    event.preventDefault()
    if (event.metaKey) this.goTo(0)
    else if (event.altKey) this.moveGroup(-1)
    else this.move(-1)
  }

  goTo(index) {
    const item = this.enabledItems.at(index)
    if (item) this.setValue(item.getAttribute("data-value"))
  }

  move(delta) {
    const items = this.enabledItems
    const index = items.indexOf(this.selectedItem)
    let target = items[index + delta]
    if (this.loopValue) target = index + delta < 0 ? items.at(-1) : index + delta === items.length ? items[0] : items[index + delta]
    if (target) this.setValue(target.getAttribute("data-value"))
  }

  moveGroup(delta) {
    const side = delta > 0 ? "nextElementSibling" : "previousElementSibling"
    let group = this.selectedItem?.closest(GROUP)
    let target = null
    while (group && !target) {
      group = this.siblingMatching(group, side, GROUP)
      target = group?.querySelector(ENABLED_ITEM)
    }
    if (target) this.setValue(target.getAttribute("data-value"))
    else this.move(delta)
  }

  siblingMatching(el, side, selector) {
    for (let sibling = el[side]; sibling; sibling = sibling[side]) if (sibling.matches(selector)) return sibling
    return null
  }

  // --- Turbo cache -----------------------------------------------------------------------------------------------------

  // A cached page shows the server state: every node mounted in source order, nothing searched, nothing selected. Only nodes
  // still in the document, or detached by this controller, come back; a node removed by a Turbo Stream stays removed.
  reset() {
    if (!this.abort) return
    this.empties.forEach((mount) => mount.unmount())
    this.empties.clear()
    this.sources.forEach((siblings, parent) => siblings.forEach((node) => {
      if (node.isConnected || this.nodes.get(node)?.mounted === false) parent.append(node)
    }))
    this.nodes.forEach((record) => { record.mounted = true })
    this.groups.forEach(({ el }) => el.removeAttribute("hidden"))
    this.items.forEach((record) => {
      record.el.setAttribute("aria-selected", "false")
      record.el.setAttribute("data-selected", "false")
    })
    for (const el of [this.input, this.list]) el?.removeAttribute("aria-activedescendant")
    const value = this.input?.getAttribute(SEARCH) ?? ""
    this.input?.setAttribute("value", value)
    if (this.input) this.input.value = value
    this.search = value
    this.current = undefined
    this.count = this.registered.length
  }
}
