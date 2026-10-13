import { Controller } from "@hotwired/stimulus"
import { presence } from "shadcn/primitives/presence"
import { direction } from "shadcn/primitives/direction"

// Radix ScrollArea behavior (docs/shadcn-port/specs/scroll-area.md, @radix-ui/react-scroll-area 1.3.0). Host = the Root div.
// Each ScrollBar waits in an inert <template> (its thumb in a nested one); mounting inserts a clone right after it.
const MIN_THUMB = 18
const ZERO_SIZES = { content: 0, viewport: 0, scrollbar: { size: 0, paddingStart: 0, paddingEnd: 0 } }
const SCROLL_MACHINE = {
  hidden: { SCROLL: "scrolling" },
  scrolling: { SCROLL_END: "idle", POINTER_ENTER: "interacting" },
  interacting: { SCROLL: "interacting", POINTER_LEAVE: "idle" },
  idle: { HIDE: "hidden", SCROLL: "scrolling", POINTER_ENTER: "interacting" }
}

export default class extends Controller {
  static targets = ["scrollbar"]
  static values = { type: { type: String, default: "hover" }, scrollHideDelay: { type: Number, default: 600 } }

  connect() {
    this.viewport = this.element.querySelector(":scope > [data-radix-scroll-area-viewport]")
    this.content = this.viewport.firstElementChild
    this.dir = direction(this.element)
    this.corner = null
    this.records = this.scrollbarTargets.map((template) => this.#record(template))
    if (this.typeValue === "hover") {
      this.element.addEventListener("pointerenter", this.onRootEnter)
      this.element.addEventListener("pointerleave", this.onRootLeave)
    }
    this.records.forEach((record) => {
      if (this.typeValue === "scroll") this.#listenScroll(record)
      this.#sync(record)
    })
  }

  disconnect() {
    this.element.removeEventListener("pointerenter", this.onRootEnter)
    this.element.removeEventListener("pointerleave", this.onRootLeave)
    this.records.forEach((record) => {
      clearTimeout(record.hideTimer)
      record.scrollEnd.cancel()
      record.stopScroll?.()
      record.stopAuto?.()
      if (record.node) this.#unmount(record)
    })
    this.#syncCorner()
  }

  // Radix sets this state from a native listener, which React 19 renders in a scheduler task, not synchronously.
  onRootEnter = () => this.records.forEach((record) => {
    clearTimeout(record.hideTimer)
    record.hideTimer = setTimeout(() => {
      record.hover = true
      this.#sync(record)
    }, 0)
  })

  onRootLeave = () => this.records.forEach((record) => {
    record.hideTimer = setTimeout(() => {
      record.hover = false
      this.#sync(record)
    }, this.scrollHideDelayValue)
  })

  #record(template) {
    const prototype = template.content.firstElementChild
    const record = {
      template, prototype, force: template.getAttribute("data-v2--scroll-area-force-mount") === "true",
      horizontal: prototype.dataset.orientation === "horizontal",
      node: null, hover: false, autoVisible: false, scrollState: "hidden", hideTimer: 0, sizes: ZERO_SIZES
    }
    record.scrollEnd = this.#debounce(() => this.#send(record, "SCROLL_END"), 100)
    return record
  }

  // ---- visibility per type (Radix ScrollAreaScrollbar{Hover,Scroll,Auto}) ----

  #wants(record) {
    switch (this.typeValue) {
      case "always": return true
      case "auto": return record.force || record.autoVisible
      case "scroll": return record.force || record.scrollState !== "hidden"
      default: return (record.force || record.hover) && record.autoVisible
    }
  }

  #dataState(record) {
    switch (this.typeValue) {
      case "always": return "visible"
      case "auto": return record.autoVisible ? "visible" : "hidden"
      case "scroll": return record.scrollState === "hidden" ? "hidden" : "visible"
      default: return record.hover ? "visible" : "hidden"
    }
  }

  #sync(record) {
    // The auto check lives above Presence for "auto", and only while the hover layer is present for "hover".
    const autoLayer = this.typeValue === "auto" || (this.typeValue === "hover" && (record.force || record.hover))
    if (autoLayer && !record.stopAuto) this.#startAuto(record)

    if (this.#wants(record)) {
      if (!record.node) this.#mount(record)
      else if (record.exiting) {
        record.exiting = false
        record.presence.enter()
      }
    }
    if (!record.node) return

    record.node.dataset.state = this.#dataState(record)
    if (!this.#wants(record) && !record.exiting) {
      record.exiting = true
      record.presence.exit()
    }
  }

  #startAuto(record) {
    const check = this.#debounce(() => {
      record.autoVisible = record.horizontal
        ? this.viewport.offsetWidth < this.viewport.scrollWidth
        : this.viewport.offsetHeight < this.viewport.scrollHeight
      this.#sync(record)
    }, 10)
    const stop = this.#observe([this.viewport, this.content], check)
    record.stopAuto = () => {
      stop()
      check.cancel()
      record.stopAuto = null
    }
  }

  #listenScroll(record) {
    const key = record.horizontal ? "scrollLeft" : "scrollTop"
    let previous = this.viewport[key]
    const onScroll = () => {
      const position = this.viewport[key]
      if (previous !== position) {
        this.#send(record, "SCROLL")
        record.scrollEnd()
      }
      previous = position
    }
    this.viewport.addEventListener("scroll", onScroll)
    record.stopScroll = () => this.viewport.removeEventListener("scroll", onScroll)
  }

  #send(record, event) {
    const next = SCROLL_MACHINE[record.scrollState][event] ?? record.scrollState
    if (next === record.scrollState) return

    clearTimeout(record.hideTimer)
    record.scrollState = next
    if (next === "idle") record.hideTimer = setTimeout(() => this.#send(record, "HIDE"), this.scrollHideDelayValue)
    this.#sync(record)
  }

  // ---- mounting ----

  #mount(record) {
    const node = record.prototype.cloneNode(true)
    record.node = node
    record.exiting = false
    record.sizes = ZERO_SIZES
    record.pointerOffset = 0
    record.rect = null
    record.thumbPlaceholder = node.querySelector(":scope > template")
    record.callerStyle = new Set(Array.from(node.style))
    node.dataset.state = this.#dataState(record)
    this.#applyStyle(record)
    record.template.after(node)
    record.presence = presence(node, { onExited: () => this.#unmount(record) })

    const disposers = []
    const listen = (target, type, handler, options) => {
      target.addEventListener(type, handler, options)
      disposers.push(() => target.removeEventListener(type, handler, options))
    }
    listen(node, "pointerdown", (event) => this.#pointerDown(record, event))
    listen(node, "pointerdown", (event) => this.#thumbPointerDown(record, event), true)
    listen(node, "pointermove", (event) => this.#dragScroll(record, event))
    listen(node, "pointerup", (event) => this.#pointerUp(record, event))
    listen(document, "wheel", (event) => this.#wheel(record, event), { passive: false })
    listen(this.viewport, "scroll", () => this.#onViewportScroll(record))
    if (this.typeValue === "scroll") {
      listen(node, "pointerenter", () => this.#send(record, "POINTER_ENTER"))
      listen(node, "pointerleave", () => this.#send(record, "POINTER_LEAVE"))
    }
    const stopSizes = this.#observe([node, this.content], this.#debounce(() => this.#measure(record), 10))
    disposers.push(stopSizes)
    record.disposers = disposers
    this.#syncCorner()
  }

  #unmount(record) {
    if (!record.node) return

    record.disposers.forEach((dispose) => dispose())
    record.unlinked?.()
    record.unlinked = null
    record.scrollStop?.cancel()
    if (record.rect) this.#endDrag(record)
    record.presence.release()
    record.node.remove()
    record.node = record.thumb = record.rect = null
    record.exiting = false
    record.sizes = ZERO_SIZES
    const hoverLayer = this.typeValue === "hover" && !(record.force || record.hover)
    if (hoverLayer) {
      record.stopAuto?.()
      record.autoVisible = false
    }
    this.#syncCorner()
  }

  #applyStyle(record) {
    const { node } = record
    const set = (property, value) => {
      if (!record.callerStyle.has(property)) node.style.setProperty(property, value)
    }
    const rtl = this.dir === "rtl"
    set("position", "absolute")
    if (record.horizontal) {
      set("bottom", "0px")
      set("left", rtl ? "var(--radix-scroll-area-corner-width)" : "0px")
      set("right", rtl ? "0px" : "var(--radix-scroll-area-corner-width)")
      set("--radix-scroll-area-thumb-width", `${this.#thumbSize(record.sizes)}px`)
    } else {
      set("top", "0px")
      set(rtl ? "left" : "right", "0px")
      set("bottom", "var(--radix-scroll-area-corner-height)")
      set("--radix-scroll-area-thumb-height", `${this.#thumbSize(record.sizes)}px`)
    }
  }

  // ---- sizes and thumb ----

  #measure(record) {
    const { node } = record
    if (!node) return

    const style = getComputedStyle(node)
    const toInt = (value) => (value ? parseInt(value, 10) : 0)
    record.sizes = record.horizontal
      ? { content: this.viewport.scrollWidth, viewport: this.viewport.offsetWidth, scrollbar: { size: node.clientWidth, paddingStart: toInt(style.paddingLeft), paddingEnd: toInt(style.paddingRight) } }
      : { content: this.viewport.scrollHeight, viewport: this.viewport.offsetHeight, scrollbar: { size: node.clientHeight, paddingStart: toInt(style.paddingTop), paddingEnd: toInt(style.paddingBottom) } }
    this.#applyStyle(record)
    const ratio = this.#thumbRatio(record.sizes)
    const hasThumb = ratio > 0 && ratio < 1
    if (hasThumb && !record.thumb) this.#mountThumb(record)
    else if (!hasThumb && record.thumb) this.#unmountThumb(record)
    this.#positionThumb(record)
  }

  #mountThumb(record) {
    const thumb = record.thumbPlaceholder.content.firstElementChild.cloneNode(true)
    record.thumbPlaceholder.after(thumb)
    record.thumb = thumb
    thumb.addEventListener("pointerup", () => { record.pointerOffset = 0 })
    this.#positionThumb(record)
  }

  #unmountThumb(record) {
    record.thumb.remove()
    record.thumb = null
  }

  #positionThumb(record) {
    if (!record.thumb) return

    const offset = record.horizontal
      ? this.#thumbOffset(this.viewport.scrollLeft, record.sizes, this.dir)
      : this.#thumbOffset(this.viewport.scrollTop, record.sizes)
    record.thumb.style.transform = record.horizontal ? `translate3d(${offset}px, 0, 0)` : `translate3d(0, ${offset}px, 0)`
  }

  // While scrolling, follow scrollLeft/scrollTop every frame until 100ms after the last scroll event (addUnlinkedScrollListener).
  #onViewportScroll(record) {
    record.scrollStop ||= this.#debounce(() => {
      record.unlinked?.()
      record.unlinked = null
    }, 100)
    record.scrollStop()
    if (record.unlinked) return

    let previous = { left: this.viewport.scrollLeft, top: this.viewport.scrollTop }
    let frame = 0
    const loop = () => {
      const position = { left: this.viewport.scrollLeft, top: this.viewport.scrollTop }
      if (previous.left !== position.left || previous.top !== position.top) this.#positionThumb(record)
      previous = position
      frame = requestAnimationFrame(loop)
    }
    loop()
    record.unlinked = () => cancelAnimationFrame(frame)
    this.#positionThumb(record)
  }

  #thumbRatio({ viewport, content }) {
    const ratio = viewport / content
    return Number.isNaN(ratio) ? 0 : ratio
  }

  #thumbSize(sizes) {
    const padding = sizes.scrollbar.paddingStart + sizes.scrollbar.paddingEnd
    return Math.max((sizes.scrollbar.size - padding) * this.#thumbRatio(sizes), MIN_THUMB)
  }

  #linearScale(input, output) {
    return (value) => {
      if (input[0] === input[1] || output[0] === output[1]) return output[0]
      const ratio = (output[1] - output[0]) / (input[1] - input[0])
      return output[0] + ratio * (value - input[0])
    }
  }

  #thumbOffset(scrollPos, sizes, dir = "ltr") {
    const thumbSize = this.#thumbSize(sizes)
    const scrollbar = sizes.scrollbar.size - (sizes.scrollbar.paddingStart + sizes.scrollbar.paddingEnd)
    const maxScroll = sizes.content - sizes.viewport
    const range = dir === "ltr" ? [0, maxScroll] : [maxScroll * -1, 0]
    const clamped = Math.min(Math.max(scrollPos, range[0]), range[1])
    return this.#linearScale([0, maxScroll], [0, scrollbar - thumbSize])(clamped)
  }

  #scrollFromPointer(pointerPos, pointerOffset, sizes, dir = "ltr") {
    const thumbSize = this.#thumbSize(sizes)
    const offset = pointerOffset || thumbSize / 2
    const minPointer = sizes.scrollbar.paddingStart + offset
    const maxPointer = sizes.scrollbar.size - sizes.scrollbar.paddingEnd - (thumbSize - offset)
    const maxScroll = sizes.content - sizes.viewport
    const range = dir === "ltr" ? [0, maxScroll] : [maxScroll * -1, 0]
    return this.#linearScale([minPointer, maxPointer], range)(pointerPos)
  }

  // ---- pointer and wheel ----

  #pointerDown(record, event) {
    if (event.button !== 0) return

    event.target.setPointerCapture(event.pointerId)
    record.rect = record.node.getBoundingClientRect()
    record.prevUserSelect = document.body.style.webkitUserSelect
    document.body.style.webkitUserSelect = "none"
    this.viewport.style.scrollBehavior = "auto"
    this.#dragScroll(record, event)
  }

  #thumbPointerDown(record, event) {
    if (!record.thumb || event.target !== record.thumb) return

    const rect = record.thumb.getBoundingClientRect()
    record.pointerOffset = record.horizontal ? event.clientX - rect.left : event.clientY - rect.top
  }

  #dragScroll(record, event) {
    if (!record.rect) return

    if (record.horizontal) {
      this.viewport.scrollLeft = this.#scrollFromPointer(event.clientX - record.rect.left, record.pointerOffset, record.sizes, this.dir)
    } else {
      this.viewport.scrollTop = this.#scrollFromPointer(event.clientY - record.rect.top, record.pointerOffset, record.sizes)
    }
  }

  #pointerUp(record, event) {
    if (event.target.hasPointerCapture(event.pointerId)) event.target.releasePointerCapture(event.pointerId)
    this.#endDrag(record)
  }

  #endDrag(record) {
    document.body.style.webkitUserSelect = record.prevUserSelect
    this.viewport.style.scrollBehavior = ""
    record.rect = null
  }

  #wheel(record, event) {
    if (!record.node?.contains(event.target)) return

    const key = record.horizontal ? "scrollLeft" : "scrollTop"
    const position = this.viewport[key] + (record.horizontal ? event.deltaX : event.deltaY)
    this.viewport[key] = position
    const max = record.sizes.content - record.sizes.viewport
    if (position > 0 && position < max) event.preventDefault()
  }

  // ---- corner (Radix ScrollAreaCorner) ----

  #syncCorner() {
    const x = this.records.find((record) => record.horizontal && record.node)?.node
    const y = this.records.find((record) => !record.horizontal && record.node)?.node
    const wanted = this.typeValue !== "scroll" && x && y
    if (this.corner && (!wanted || this.corner.x !== x || this.corner.y !== y)) this.#removeCorner()
    if (wanted && !this.corner) this.#addCorner(x, y)
  }

  #addCorner(x, y) {
    const corner = { x, y, width: 0, height: 0, node: null }
    const stopX = this.#observe([x], () => this.#cornerSize(corner, "height", x.offsetHeight || 0))
    const stopY = this.#observe([y], () => this.#cornerSize(corner, "width", y.offsetWidth || 0))
    corner.stop = () => {
      stopX()
      stopY()
    }
    this.corner = corner
  }

  #cornerSize(corner, axis, size) {
    corner[axis] = size
    this.element.style.setProperty(`--radix-scroll-area-corner-${axis}`, `${size}px`)
    if (!(corner.width && corner.height)) {
      corner.node?.remove()
      corner.node = null
      return
    }

    corner.node ||= this.element.appendChild(document.createElement("div"))
    const rtl = this.dir === "rtl"
    corner.node.style.cssText = `width: ${corner.width}px; height: ${corner.height}px; position: absolute; ${rtl ? "left" : "right"}: 0px; bottom: 0px;`
  }

  #removeCorner() {
    this.corner.stop()
    this.corner.node?.remove()
    this.corner = null
    this.element.style.setProperty("--radix-scroll-area-corner-width", "0px")
    this.element.style.setProperty("--radix-scroll-area-corner-height", "0px")
  }

  // ---- helpers ----

  // useResizeObserver: each notification coalesced into one animation frame.
  #observe(elements, callback) {
    let frame = 0
    const observer = new ResizeObserver(() => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(callback)
    })
    elements.forEach((element) => observer.observe(element))
    return () => {
      cancelAnimationFrame(frame)
      observer.disconnect()
    }
  }

  // useDebounceCallback
  #debounce(callback, delay) {
    let timer = 0
    const debounced = () => {
      clearTimeout(timer)
      timer = setTimeout(callback, delay)
    }
    debounced.cancel = () => clearTimeout(timer)
    return debounced
  }
}
