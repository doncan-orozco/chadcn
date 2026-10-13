import { Controller } from "@hotwired/stimulus"
import { pointerCapture } from "shadcn/primitives/pointer_capture"
import { direction } from "shadcn/primitives/direction"

// Radix Slider behavior (docs/shadcn-port/specs/slider.md). Host = the root span; thumbs, range and bubble inputs are
// children rendered by the server. Thumb elements never move: values are re-sorted across them.
const PAGE_KEYS = ["PageUp", "PageDown"]
const ARROW_KEYS = ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"]
const BACK_KEYS = {
  "from-left": ["Home", "PageDown", "ArrowDown", "ArrowLeft"],
  "from-right": ["Home", "PageDown", "ArrowDown", "ArrowRight"],
  "from-bottom": ["Home", "PageDown", "ArrowDown", "ArrowLeft"],
  "from-top": ["Home", "PageDown", "ArrowUp", "ArrowLeft"]
}

export default class extends Controller {
  static values = {
    min: Number, max: Number, step: Number, orientation: String, inverted: Boolean, disabled: Boolean,
    controlled: Boolean, minStepsBetweenThumbs: Number, preserveThumbOrder: Boolean, form: String
  }

  connect() {
    this.thumbs = [...this.element.querySelectorAll("[data-slot=slider-thumb]")]
    this.values = this.thumbs.filter((thumb) => thumb.hasAttribute("aria-valuenow")).map((thumb) => Number(thumb.getAttribute("aria-valuenow")))
    this.initialValues = this.values
    this.snapshot = this.values
    this.activeIndex = 0
    this.keyboard = false
    this.sizes = this.thumbs.map(() => ({ width: 0, height: 0 }))
    this.horizontal = this.orientationValue !== "vertical"
    this.#removeNonFormInputs()
    this.#observeSizes()
    this.#applyOffsets()
    this.drag = pointerCapture(this.element, {
      filter: (event) => !event.defaultPrevented,
      onStart: (event) => this.#pointerStart(event),
      onMove: (event) => this.#slide(event, false),
      onEnd: () => this.#slideEnd()
    })
    this.element.addEventListener("keydown", this.onKeydown)
    this.element.addEventListener("focusin", this.onFocusin)
    this.form = this.formValue ? this.element.ownerDocument.getElementById(this.formValue) : this.element.closest("form")
    this.form?.addEventListener("reset", this.onReset)
  }

  disconnect() {
    this.drag?.release()
    this.element.removeEventListener("keydown", this.onKeydown)
    this.element.removeEventListener("focusin", this.onFocusin)
    this.form?.removeEventListener("reset", this.onReset)
    this.observers?.forEach((observer) => observer.disconnect())
    this.frames?.forEach((frame) => cancelAnimationFrame(frame))
    this.rect = undefined
  }

  onReset = () => this.#setValues(this.initialValues)

  onFocusin = (event) => {
    const index = this.thumbs.indexOf(event.target)
    if (index >= 0) this.activeIndex = index
  }

  onKeydown = (event) => {
    if (event.defaultPrevented) return
    if (event.key === "Home") {
      if (!this.disabledValue) this.#keyboardUpdate(this.minValue, 0)
    } else if (event.key === "End") {
      if (!this.disabledValue) this.#keyboardUpdate(this.maxValue, this.values.length - 1)
    } else if (PAGE_KEYS.concat(ARROW_KEYS).includes(event.key)) {
      if (!this.disabledValue) this.#stepKey(event)
    } else return
    event.preventDefault()
  }

  #keyboardUpdate(value, index) {
    this.keyboard = true
    this.#updateValues(value, index, true)
  }

  #stepKey(event) {
    this.keyboard = true
    const back = BACK_KEYS[this.#slideDirection].includes(event.key)
    const skip = PAGE_KEYS.includes(event.key) || (event.shiftKey && ARROW_KEYS.includes(event.key))
    const index = this.activeIndex
    const next = this.#nextStepValue(this.values[index], back ? -1 : 1, skip ? 10 : 1)
    this.#updateValues(next, index, true)
  }

  get #slideDirection() {
    return this.horizontal ? (this.#fromStart ? "from-left" : "from-right") : (this.#fromStart ? "from-bottom" : "from-top")
  }

  // Horizontal: the left edge is the start when (ltr xor inverted); vertical: the bottom unless inverted.
  get #fromStart() {
    if (!this.horizontal) return !this.invertedValue
    return (direction(this.element) === "ltr") !== this.invertedValue
  }

  get #startEdge() {
    return this.horizontal ? (this.#fromStart ? "left" : "right") : (this.#fromStart ? "bottom" : "top")
  }

  #pointerStart(event) {
    if (!this.disabledValue) {
      this.snapshot = this.values
      this.keyboard = false
    }
    if (this.thumbs.includes(event.target)) event.target.focus({ preventScroll: true, focusVisible: false })
    else this.#slide(event, true)
  }

  #slide(event, start) {
    if (this.disabledValue) return
    const value = this.#valueFromPointer(event)
    this.#updateValues(value, start ? this.#closestIndex(value) : this.activeIndex)
  }

  #slideEnd() {
    this.rect = undefined
    if (this.disabledValue) return
    if (String(this.values) !== String(this.snapshot)) this.#dispatch("value-commit", this.values)
  }

  #valueFromPointer(event) {
    const rect = this.rect || this.element.getBoundingClientRect()
    this.rect = rect
    const { minValue: min, maxValue: max } = this
    if (this.horizontal) {
      return linearScale([0, rect.width], this.#fromStart ? [min, max] : [max, min])(event.clientX - rect.left)
    }
    return linearScale([0, rect.height], this.#fromStart ? [max, min] : [min, max])(event.clientY - rect.top)
  }

  #closestIndex(value) {
    if (this.values.length === 1) return 0
    const distances = this.values.map((v) => Math.abs(v - value))
    return distances.indexOf(Math.min(...distances))
  }

  #updateValues(value, atIndex, commit = false) {
    const { minValue: min, maxValue: max, stepValue: step } = this
    const prev = this.values
    const snapped = roundValue(Math.round((value - min) / step) * step + min, decimalCount(step))
    const nextValue = clamp(snapped, min, max)
    const distance = this.minStepsBetweenThumbsValue * step
    const constrained = this.preserveThumbOrderValue
      ? clamp(
        nextValue,
        prev[atIndex - 1] === undefined ? min : prev[atIndex - 1] + distance,
        prev[atIndex + 1] === undefined ? max : prev[atIndex + 1] - distance
      )
      : nextValue
    const next = [...prev]
    next[atIndex] = constrained
    next.sort((a, b) => a - b)
    if (!hasMinSteps(next, distance)) return
    this.activeIndex = this.preserveThumbOrderValue ? atIndex : next.indexOf(constrained)
    if (String(next) === String(prev)) return
    if (commit) this.#dispatch("value-commit", next)
    this.#change(next)
  }

  #setValues(next) {
    if (String(next) !== String(this.values)) this.#change(next)
  }

  // Radix onChange: focus the affected thumb, then notify. Controlled sliders keep their DOM until the caller re-renders.
  #change(next) {
    if (!this.controlledValue) {
      const previous = this.values
      this.values = next
      this.#render(previous)
    }
    this.thumbs[this.activeIndex]?.focus({ preventScroll: true, focusVisible: this.keyboard })
    this.keyboard = false
    this.#dispatch("value-change", next)
  }

  #render(previous) {
    this.thumbs.forEach((thumb, index) => {
      const value = this.values[index]
      if (value !== undefined) thumb.setAttribute("aria-valuenow", value)
      this.#syncInput(thumb, value, previous[index])
    })
    this.#applyOffsets()
    this.#applyRange()
  }

  #applyRange() {
    const range = this.element.querySelector("[data-slot=slider-range]")
    const percents = this.values.map((value) => this.#percent(value))
    const start = percents.length > 1 ? Math.min(...percents) : 0
    const end = 100 - Math.max(...percents)
    const edges = this.horizontal ? (this.#fromStart ? ["left", "right"] : ["right", "left"]) : (this.#fromStart ? ["bottom", "top"] : ["top", "bottom"])
    range.style.setProperty(edges[0], `${start}%`)
    range.style.setProperty(edges[1], `${end}%`)
  }

  #applyOffsets() {
    const sign = this.#fromStart ? 1 : -1
    this.thumbs.forEach((thumb, index) => {
      const value = this.values[index]
      const percent = value === undefined ? 0 : this.#percent(value)
      const size = this.sizes[index][this.horizontal ? "width" : "height"]
      const offset = size ? inBoundsOffset(size, percent, sign) : 0
      thumb.parentElement.style.setProperty(this.#startEdge, `calc(${percent}% + ${offset}px)`)
    })
  }

  #percent(value) {
    return clamp((100 / (this.maxValue - this.minValue)) * (value - this.minValue), 0, 100)
  }

  #syncInput(thumb, value, previous) {
    const input = thumb.parentElement.nextElementSibling
    if (input?.tagName !== "INPUT" || value === undefined) return
    input.setAttribute("value", value)
    if (value === previous) return
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(input, value)
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // The server always renders the inputs (like Radix before mount); outside a form they do not exist in Radix.
  #removeNonFormInputs() {
    this.thumbs.forEach((thumb) => {
      const input = thumb.parentElement.nextElementSibling
      if (input?.tagName === "INPUT" && !this.formValue && !thumb.closest("form")) input.remove()
    })
  }

  // Radix useSize: initial offset size, then border-box size on the next frame after a resize.
  #observeSizes() {
    this.frames = []
    this.observers = this.thumbs.map((thumb, index) => {
      this.sizes[index] = { width: thumb.offsetWidth, height: thumb.offsetHeight }
      const observer = new ResizeObserver((entries) => {
        const entry = entries[0]
        if (!entry) return
        cancelAnimationFrame(this.frames[index])
        this.frames[index] = requestAnimationFrame(() => {
          const box = [].concat(entry.borderBoxSize)[0]
          this.sizes[index] = box ? { width: box.inlineSize, height: box.blockSize } : { width: thumb.offsetWidth, height: thumb.offsetHeight }
          this.#applyOffsets()
        })
      })
      observer.observe(thumb, { box: "border-box" })
      return observer
    })
  }

  #nextStepValue(value, stepDirection, multiplier) {
    const { minValue: min, stepValue: step } = this
    const decimals = decimalCount(step)
    const stepsFromMin = (value - min) / step
    const nearest = Math.round(stepsFromMin)
    const aligned = roundValue(nearest * step + min, decimals) === roundValue(value, decimals)
    let nextSteps
    if (aligned) nextSteps = nearest + multiplier * stepDirection
    else if (stepDirection > 0) nextSteps = Math.ceil(stepsFromMin)
    else nextSteps = Math.floor(stepsFromMin)
    return roundValue(nextSteps * step + min, decimals)
  }

  #dispatch(name, value) {
    this.element.dispatchEvent(new CustomEvent(`v2--slider:${name}`, { detail: { value }, bubbles: true }))
  }
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}

function hasMinSteps(values, distance) {
  if (distance <= 0) return true
  const gaps = values.slice(0, -1).map((value, index) => values[index + 1] - value)
  return Math.min(...gaps) >= distance
}

function linearScale(input, output) {
  return (value) => {
    if (input[0] === input[1] || output[0] === output[1]) return output[0]
    const ratio = (output[1] - output[0]) / (input[1] - input[0])
    return output[0] + ratio * (value - input[0])
  }
}

function inBoundsOffset(width, left, sign) {
  const half = width / 2
  const offset = linearScale([0, 50], [0, half])
  return (half - offset(left) * sign) * sign
}

function decimalCount(value) {
  if (!Number.isFinite(value)) return 0
  const string = value.toString()
  if (string.includes("e")) {
    const [coefficient, exponent] = string.split("e")
    return Math.max(0, (coefficient.split(".")[1] || "").length - Number(exponent))
  }
  return (string.split(".")[1] || "").length
}

function roundValue(value, decimals) {
  const rounder = Math.pow(10, decimals)
  return Math.round(value * rounder) / rounder
}
