import { Controller } from "@hotwired/stimulus"
import { mountTemplate, mountedTemplate } from "chadcn/primitives/template_mount"
import { turboCacheRestore } from "chadcn/primitives/turbo_cache"

// Radix Avatar loading status (dev/port/specs/avatar.md). Host = the Avatar root.
// Image and delayed Fallback parts wait in inert <template>s and mount through the template_mount primitive: the image right
// after its template (which stays), a fallback in its template's place (unmounting puts the template back, holding it).
export default class extends Controller {
  static targets = ["image", "fallback"]

  connect() {
    this.#setup()
    // A page snapshot must hold the server markup (the image as its template, the fallback in place), not the mounted image
    // next to an emptied fallback template that a restored controller could not clone.
    this.cache = turboCacheRestore({ teardown: () => this.#teardown(), restore: () => this.#setup() })
  }

  disconnect() {
    this.cache?.release()
    this.#teardown()
  }

  #setup() {
    this.status = "idle"
    this.fallbacks = this.fallbackTargets.map((el) => this.#fallbackRecord(el))
    this.imageRecord = this.hasImageTarget ? { template: this.imageTarget, mount: null } : null
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

  // A delayed fallback arrives as its template; one rendered in place is adopted as the mount of a template built to hold it.
  #fallbackRecord(el) {
    const isTemplate = el.tagName === "TEMPLATE"
    const delayAttr = isTemplate ? el.getAttribute("data-chadcn--avatar-delay-ms") : null
    const delay = delayAttr === null ? null : Number(delayAttr)
    if (isTemplate) return { delay, canRender: delay === null, template: el, mount: null }

    const template = document.createElement("template")
    template.setAttribute("data-chadcn--avatar-target", "fallback")
    template.content.append(el.cloneNode(true))
    return { delay, canRender: delay === null, template, mount: mountedTemplate(template, [el], { into: "replace" }) }
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
    this.element.dispatchEvent(new CustomEvent("chadcn--avatar:loading-status-change", { detail: { status }, bubbles: true }))
  }

  #render() {
    const loaded = this.status === "loaded"
    this.#toggleImage(loaded)
    this.fallbacks.forEach((record) => this.#toggleFallback(record, record.canRender && !loaded))
  }

  #toggleImage(mounted) {
    const record = this.imageRecord
    if (!record || mounted === Boolean(record.mount)) return
    this.#toggle(record, mounted, "after")
  }

  #toggleFallback(record, mounted) {
    if (mounted === Boolean(record.mount) || (mounted && !record.template.content.firstElementChild)) return
    this.#toggle(record, mounted, "replace")
  }

  #toggle(record, mounted, into) {
    if (mounted) {
      record.mount = mountTemplate(record.template, { into })
    } else {
      record.mount.unmount()
      record.mount = null
    }
  }
}
