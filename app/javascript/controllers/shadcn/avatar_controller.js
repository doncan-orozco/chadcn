import { Controller } from "@hotwired/stimulus"

// Radix Avatar loading status (docs/shadcn-port/specs/avatar.md). Host = the Avatar root.
// Image and delayed Fallback parts wait in inert <template>s; mounting swaps the template for a fresh clone in place.
export default class extends Controller {
  static targets = ["image", "fallback"]

  restoreTimer = null

  connect() {
    this.#setup()
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    clearTimeout(this.restoreTimer)
    this.#teardown()
  }

  #setup() {
    this.status = "idle"
    this.fallbacks = this.fallbackTargets.map((el) => this.#fallbackRecord(el))
    this.imageRecord = this.hasImageTarget ? { template: this.imageTarget, node: null } : null
    this.fallbacks.forEach((record) => this.#startDelay(record))
    this.#render()
    if (this.imageRecord) this.#loadImage()
  }

  #teardown() {
    this.#cleanupImage()
    this.fallbacks?.forEach((record) => {
      clearTimeout(record.timer)
      record.canRender = record.delay === null
    })
    this.status = "idle"
    this.#render()
  }

  // A page snapshot must hold the server markup (the image as its template, the fallback in place), not the mounted image
  // next to an emptied fallback template that a restored controller could not clone. Turbo takes the snapshot one timer tick
  // after this event (hence the two ticks below) and also for visits that keep the page (a link to #hash), so the controller
  // is set up again once the snapshot is taken; a real navigation disconnects it first, which cancels that.
  onBeforeCache = () => {
    clearTimeout(this.restoreTimer)
    this.#teardown()
    this.restoreTimer = setTimeout(() => {
      this.restoreTimer = setTimeout(() => this.#setup())
    })
  }

  #fallbackRecord(el) {
    const isTemplate = el.tagName === "TEMPLATE"
    const delayAttr = isTemplate ? el.getAttribute("data-shadcn--avatar-delay-ms") : null
    const delay = delayAttr === null ? null : Number(delayAttr)
    const record = { delay, canRender: delay === null, node: null, prototype: null, placeholder: null }
    if (isTemplate) {
      record.placeholder = el
      record.prototype = el.content.firstElementChild
    } else {
      record.node = el
      record.prototype = el.cloneNode(true)
      record.placeholder = document.createElement("template")
      record.placeholder.setAttribute("data-shadcn--avatar-target", "fallback")
    }
    return record
  }

  #startDelay(record) {
    if (record.delay === null) return
    record.timer = setTimeout(() => {
      record.canRender = true
      this.#render()
    }, record.delay)
  }

  #loadImage() {
    const source = this.imageRecord.template.content.firstElementChild
    const src = source?.getAttribute("src")
    if (!src) return this.#setStatus("error")

    const image = new window.Image()
    const onLoad = () => this.#setStatus(this.#statusOf(image))
    const onError = () => this.#setStatus("error")
    image.addEventListener("load", onLoad)
    image.addEventListener("error", onError)
    const referrerPolicy = source.getAttribute("referrerpolicy")
    if (referrerPolicy) image.referrerPolicy = referrerPolicy
    image.crossOrigin = source.getAttribute("crossorigin")
    image.src = src
    this.stopLoading = () => {
      image.removeEventListener("load", onLoad)
      image.removeEventListener("error", onError)
      image.src = "" // the detached image stops loading
    }
    this.#setStatus(this.#statusOf(image))
  }

  #cleanupImage() {
    this.stopLoading?.()
    this.stopLoading = null
  }

  #statusOf(image) {
    if (!image.complete) return "loading"
    return image.naturalWidth > 0 ? "loaded" : "error"
  }

  #setStatus(status) {
    if (status === this.status) return
    this.status = status
    this.#render()
    this.element.dispatchEvent(new CustomEvent("shadcn--avatar:loading-status-change", { detail: { status }, bubbles: true }))
  }

  #render() {
    const loaded = this.status === "loaded"
    this.#toggleImage(loaded)
    this.fallbacks.forEach((record) => this.#toggleFallback(record, record.canRender && !loaded))
  }

  #toggleImage(mounted) {
    const record = this.imageRecord
    if (!record || mounted === Boolean(record.node)) return
    if (mounted) {
      record.node = record.template.content.firstElementChild.cloneNode(true)
      record.template.after(record.node)
    } else {
      record.node.remove()
      record.node = null
    }
  }

  #toggleFallback(record, mounted) {
    if (mounted === Boolean(record.node) || (mounted && !record.prototype)) return
    if (mounted) {
      record.node = record.prototype.cloneNode(true)
      record.placeholder.replaceWith(record.node)
    } else {
      record.node.replaceWith(record.placeholder)
      record.node = null
    }
  }
}
