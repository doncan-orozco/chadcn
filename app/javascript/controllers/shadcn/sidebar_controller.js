import { Controller } from "@hotwired/stimulus"

// shadcn SidebarProvider + useSidebar + useIsMobile. Spec: docs/shadcn-port/specs/sidebar.md (Behavior).
//
// The controller element is the Provider wrapper. Desktop is CSS only: data-state / data-collapsible change on the
// outer [data-slot=sidebar] node. On a mobile viewport React renders a Sheet INSTEAD of that node, so the controller
// detaches the desktop node, mounts the Sheet host from the sibling <template> in its place and moves the single
// server-rendered copy of the block into the Sheet body when it opens (and back on desktop).
const MOBILE_BREAKPOINT = 768
const COOKIE_NAME = "sidebar_state"
const COOKIE_MAX_AGE = 60 * 60 * 24 * 7
const KEYBOARD_SHORTCUT = "b"
const TOGGLE_ACTION = "shadcn--sidebar#toggle"

export default class extends Controller {
  static values = { open: Boolean, controlled: Boolean, openMobile: Boolean, id: String }
  static targets = ["sidebar"]

  connect() {
    this.isMobile = false
    this.records = this.sidebarTargets.map((desktop) => ({ desktop, template: this.#templateOf(desktop), host: null, nodes: [] }))
    this.abort = new AbortController()
    this.query = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)
    this.query.addEventListener("change", () => this.#syncMobile(), { signal: this.abort.signal })
    window.addEventListener("keydown", (event) => this.#onKeydown(event), { signal: this.abort.signal })
    document.addEventListener("turbo:before-cache", () => this.#leaveMobile(), { signal: this.abort.signal })
    this.#syncMobile()
    this.#syncTooltips()
  }

  // A cached page must hold the server structure: put the desktop nodes back.
  disconnect() {
    this.abort.abort()
    this.#leaveMobile()
  }

  toggle() {
    if (this.isMobile) this.#setOpenMobile(!this.openMobileValue)
    else this.#setOpen(!this.openValue)
  }

  setOpen(event) {
    this.#setOpen(Boolean(event.params.open))
  }

  setOpenMobile(event) {
    this.#setOpenMobile(Boolean(event.params.open))
  }

  openValueChanged() {
    if (!this.records) return
    this.#syncDesktop()
    this.#syncTooltips()
  }

  openMobileValueChanged() {
    if (this.records) this.#syncSheets()
  }

  // --- state -------------------------------------------------------------------------------------------------------

  // useControllableState: the event always fires, the DOM only changes when uncontrolled. The cookie is written in both modes.
  #setOpen(value) {
    this.dispatch("open-change", { detail: { open: value } })
    if (!this.controlledValue) {
      this.openValue = value
      this.#syncDesktop()
      this.#syncTooltips()
    }
    document.cookie = `${COOKIE_NAME}=${value}; path=/; max-age=${COOKIE_MAX_AGE}`
  }

  #setOpenMobile(value) {
    this.dispatch("open-mobile-change", { detail: { open: value } })
    this.openMobileValue = value
    this.#syncSheets()
  }

  #onKeydown(event) {
    if (event.key !== KEYBOARD_SHORTCUT || !(event.metaKey || event.ctrlKey)) return
    event.preventDefault()
    this.toggle()
  }

  #syncDesktop() {
    const state = this.openValue ? "expanded" : "collapsed"
    this.records.forEach(({ desktop }) => {
      desktop.dataset.state = state
      desktop.dataset.collapsible = this.openValue ? "" : desktop.getAttribute("data-shadcn--sidebar-collapsible-param")
    })
  }

  // The tooltip content is hidden unless the sidebar is collapsed on desktop (tsx:541). It lives in an inert template
  // until the tooltip opens, and in the body while open: both are kept current. A caller hidden is never marked.
  #syncTooltips() {
    const hidden = this.isMobile || this.openValue
    const selector = `[data-shadcn--sidebar-tooltip="${this.idValue}"]`
    const roots = [document, ...this.records.map(({ desktop }) => desktop)]
    const contents = roots.flatMap((root) => [
      ...root.querySelectorAll(selector),
      ...[...root.querySelectorAll("template")].flatMap((template) => [...template.content.querySelectorAll(selector)])
    ])
    contents.forEach((content) => (content.hidden = hidden))
  }

  // --- mobile ------------------------------------------------------------------------------------------------------

  #templateOf(desktop) {
    const sibling = desktop.nextElementSibling
    return sibling?.matches("template[data-shadcn--sidebar-target=mobile]") ? sibling : null
  }

  // useIsMobile reads innerWidth on every media query change (mobile:5-19).
  #syncMobile() {
    const mobile = window.innerWidth < MOBILE_BREAKPOINT
    if (mobile === this.isMobile) return
    this.isMobile = mobile
    if (mobile) this.#enterMobile()
    else this.#leaveMobile()
    this.#syncTooltips()
  }

  #enterMobile() {
    this.records.forEach((record) => {
      if (!record.template || record.host) return
      const inner = record.desktop.querySelector("[data-slot=sidebar-inner]")
      record.nodes = [...inner.childNodes]
      record.host = record.template.content.firstElementChild.cloneNode(true)
      record.host.setAttribute("data-shadcn--sheet-open-value", String(this.openMobileValue))
      record.host.addEventListener("shadcn--sheet:open-auto-focus", () => this.#fillBody(record))
      record.host.addEventListener("shadcn--sheet:open-change", (event) => this.#setOpenMobile(event.detail.open))
      record.desktop.replaceWith(record.host)
    })
  }

  // Unmount the Sheet as React does: the host goes away with its mounted content, no exit animation.
  #leaveMobile() {
    this.isMobile = false
    this.records?.forEach((record) => {
      if (!record.host) return
      record.desktop.querySelector("[data-slot=sidebar-inner]").append(...record.nodes)
      record.host.replaceWith(record.desktop)
      record.host = null
    })
  }

  #syncSheets() {
    this.records.forEach(({ host }) => {
      if (host) host.setAttribute("data-shadcn--sheet-open-value", String(this.openMobileValue))
    })
  }

  // The moved nodes reconnect their controllers on the next microtask, after FocusScope focused the first tabbable: a
  // tooltip trigger would miss its focus event (React attaches the handler at render), so it is replayed once.
  #replayFocus(body) {
    queueMicrotask(() => {
      const active = document.activeElement
      if (active && active !== body && body.contains(active)) active.dispatchEvent(new FocusEvent("focus"))
    })
  }

  // The Sheet content is mounted in the body: runs before FocusScope looks for the first tabbable (open-auto-focus).
  // Stimulus actions do not reach there, so the toggle buttons are handled by delegation on the body.
  #fillBody(record) {
    const content = document.getElementById(record.host.getAttribute("data-shadcn--sheet-id-value"))
    const body = content?.querySelector("[data-shadcn--sidebar-target=mobileBody]")
    if (!body) return
    body.append(...record.nodes)
    this.#replayFocus(body)
    body.addEventListener("click", (event) => {
      if (event.defaultPrevented) return
      if (event.target.closest?.(`[data-action~='click->${TOGGLE_ACTION}']`)) this.toggle()
    })
  }
}
