import { Controller } from "@hotwired/stimulus"
import { ToastStack, toast } from "shadcn/primitives/toast_stack"

// shadcn Toaster (sonner). Spec: dev/port/specs/sonner.md (Behavior). The controller element is the Toaster <section>.
// Three ways to show a toast, all ending in the shared store of the toast_stack primitive:
//   1. JS:           window.Toaster.success("Saved", { description: "..." })   (the same function as `toast` of sonner)
//   2. Server:       <template data-shadcn--sonner-toast ...> children of the section (Sonner::Toast): the flash rendered with the page, or a
//                    Turbo Stream `append` onto the section's id. The controller turns each template into a toast and removes it.
//   3. Any element:  dispatch `shadcn--sonner:show` (bubbles to document) with detail { message, type, ...toast options }.
// Events out (dispatched on the section, bubbling): `shadcn--sonner:dismiss`, `:auto-close`, `:action`, `:cancel` with detail { id, name }.
const SHOW = "shadcn--sonner:show"
const SHOW_TYPES = ["success", "info", "warning", "error", "loading"]
const showFor = (type) => (SHOW_TYPES.includes(type) ? toast[type] : toast.message)

if (typeof window !== "undefined") {
  window.Toaster ||= toast
  if (!window.__shadcnSonnerShow) {
    window.__shadcnSonnerShow = true
    document.addEventListener(SHOW, (event) => {
      const { message, type, ...data } = event.detail || {}
      showFor(type)(message, data)
    })
  }
}

export default class extends Controller {
  static values = {
    position: { type: String, default: "bottom-right" },
    theme: { type: String, default: "system" },
    richColors: Boolean,
    expand: Boolean,
    closeButton: Boolean,
    invert: Boolean,
    duration: Number,
    visibleToasts: { type: Number, default: 3 },
    gap: { type: Number, default: 14 },
    offset: String,
    mobileOffset: String,
    dir: String,
    hotkey: { type: Array, default: ["altKey", "KeyT"] },
    swipeDirections: Array,
    toastOptions: Object,
    className: String,
    style: Object,
    toasterId: String
  }

  connect() {
    this.stack = new ToastStack(this.element, this.config())
    this.stack.connect()
    this.ingest()
    this.observer = new MutationObserver(() => this.ingest())
    this.observer.observe(this.element, { childList: true })
    // A cached page must not come back with toasts on screen.
    this.beforeCache = () => this.stack.disconnect()
    document.addEventListener("turbo:before-cache", this.beforeCache)
  }

  disconnect() {
    this.observer?.disconnect()
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    this.stack?.disconnect()
    this.stack = null
  }

  // Stimulus action: `data-action="click->shadcn--sonner#show"` with `data-shadcn--sonner-message-param` (and `-type-param`,
  // `-description-param`) on a button INSIDE the Toaster; use the `shadcn--sonner:show` event for triggers elsewhere.
  show({ params }) {
    const { message, type, ...data } = params
    showFor(type)(message, data)
  }

  // Stimulus action: dismisses one toast (`id` param) or all of them.
  dismiss({ params }) {
    toast.dismiss(params.id)
  }

  config() {
    const has = (name) => this[`has${name}Value`]
    return {
      position: this.positionValue,
      theme: this.themeValue,
      richColors: has("RichColors") ? this.richColorsValue : undefined,
      expand: this.expandValue,
      closeButton: this.closeButtonValue,
      invert: this.invertValue || undefined,
      duration: has("Duration") ? this.durationValue : undefined,
      visibleToasts: this.visibleToastsValue,
      gap: this.gapValue,
      offset: this.parse(this.offsetValue),
      mobileOffset: this.parse(this.mobileOffsetValue),
      dir: this.dirValue || undefined,
      hotkey: this.hotkeyValue,
      swipeDirections: has("SwipeDirections") ? this.swipeDirectionsValue : undefined,
      toastOptions: this.toastOptionsValue,
      className: this.classNameValue,
      style: this.styleValue,
      toasterId: this.toasterIdValue || undefined,
      iconFor: (name) => this.icon(name),
      emit: (name, detail) => this.dispatch(name, { detail })
    }
  }

  parse(value) {
    if (!value) return undefined
    try {
      return JSON.parse(value)
    } catch {
      return value
    }
  }

  // Icons are server-rendered once, as inert templates, so they stay the Phlex icons: `false` = the type has no icon on purpose.
  icon(name) {
    const template = this.element.querySelector(`:scope > template[data-shadcn--sonner-icon="${CSS.escape(name)}"]`)
    if (!template) return null
    if (template.hasAttribute("data-none")) return false
    return template.content.firstElementChild?.cloneNode(true) ?? null
  }

  // Turns every <template data-shadcn--sonner-toast> child into a toast (flash on page load, Turbo Stream append later).
  ingest() {
    this.element.querySelectorAll(":scope > template[data-shadcn--sonner-toast]").forEach((template) => {
      template.remove()
      const data = template.dataset
      const title = template.content.querySelector("[data-title]")?.textContent ?? ""
      const description = template.content.querySelector("[data-description]")?.textContent
      const type = data.type && data.type !== "default" ? data.type : undefined
      const options = this.options(data, description)
      showFor(type)(title, options)
    })
  }

  options(data, description) {
    const bool = (value) => (value === undefined ? undefined : value === "true")
    const options = { description: description || undefined, className: data.className || undefined, position: data.position || undefined, testId: data.testId || undefined }
    if (data.id) options.id = data.id
    if (data.duration) options.duration = Number(data.duration)
    if (data.toasterId) options.toasterId = data.toasterId
    ;["dismissible", "closeButton", "richColors", "invert", "unstyled"].forEach((key) => {
      const value = bool(data[key])
      if (value !== undefined) options[key] = value
    })
    if (data.icon === "none") options.icon = null
    if (data.actionLabel) options.action = this.button("action", data.actionLabel, data.actionHref, data.actionEvent, data.id)
    if (data.cancelLabel) options.cancel = this.button("cancel", data.cancelLabel, data.cancelHref, data.cancelEvent, data.id)
    return options
  }

  button(kind, label, href, name, id) {
    return {
      label,
      onClick: (event) => {
        this.dispatch(kind, { detail: { id, name } })
        if (href && !this.safeHref(href)) console.warn(`shadcn--sonner: ignored the non-http(s) href ${href}`)
        if (href && this.safeHref(href)) {
          event.preventDefault() // keeps the toast, the page is leaving
          window.Turbo?.visit ? window.Turbo.visit(href) : (window.location.href = href)
        }
      }
    }
  }

  safeHref(href) {
    try {
      return ["http:", "https:"].includes(new URL(href, window.location.href).protocol)
    } catch {
      return false
    }
  }
}
