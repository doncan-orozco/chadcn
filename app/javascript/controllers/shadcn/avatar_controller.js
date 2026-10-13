import { Controller } from "@hotwired/stimulus"

// Radix Avatar loading status (docs/shadcn-port/specs/avatar.md). Host = the Avatar root.
// Image and delayed Fallback parts wait in inert <template>s; mounting swaps the template for a fresh clone in place.
export default class extends Controller {
  static targets = ["image", "fallback"]

  connect() {
    this.status = "idle"
    this.fallbacks = this.fallbackTargets.map((el) => this.#fallbackRecord(el))
    this.imageRecord = this.hasImageTarget ? { template: this.imageTarget, node: null } : null
    this.fallbacks.forEach((record) => this.#startDelay(record))
    this.#render()
    if (this.imageRecord) this.#loadImage()
  }

  disconnect() {
    this.#cleanupImage()
    this.fallbacks?.forEach((record) => {
      clearTimeout(record.timer)
      record.canRender = record.delay === null
    })
    this.status = "idle"
    this.#render()
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
    if (mounted === Boolean(record.node)) return
    if (mounted) {
      record.node = record.prototype.cloneNode(true)
      record.placeholder.replaceWith(record.node)
    } else {
      record.node.replaceWith(record.placeholder)
      record.node = null
    }
  }
}
