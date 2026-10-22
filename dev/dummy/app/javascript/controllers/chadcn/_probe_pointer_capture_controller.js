import { Controller } from "@hotwired/stimulus"
import { pointerCapture } from "chadcn/primitives/pointer_capture"

// Parity probe for chadcn/primitives/pointer_capture (scenario _primitives-pointer-capture). Twin of
// react-shadcn-catalog/src/parity/primitives/pointer_capture.tsx: a slider root whose value comes from the pointer
// position (Radix SliderHorizontal math: linear scale over the root rect, clamp, snap to step). Not shipped to components.
export default class extends Controller {
  static targets = ["root", "thumb", "readout"]

  get minValue() { return Number(this.element.dataset.probeMin ?? 0) }
  get maxValue() { return Number(this.element.dataset.probeMax ?? 100) }
  get stepValue() { return Number(this.element.dataset.probeStep ?? 1) }

  connect() {
    this.value = Number(this.element.dataset.probeValue ?? 25)
    this.state = { commits: 0, moves: 0, captured: 0, startValue: this.value }
    this.drag = pointerCapture(this.rootTarget, {
      onStart: (event) => this.#start(event),
      onMove: (event) => this.#update(this.#fromPointer(event)),
      onEnd: () => this.#end()
    })
    this.rootTarget.addEventListener("pointermove", this.#count)
    this.#render()
  }

  disconnect() {
    this.drag.release()
    this.rootTarget.removeEventListener("pointermove", this.#count)
  }

  #start(event) {
    this.state.startValue = this.value
    if (event.target === this.thumbTarget) return this.thumbTarget.focus({ preventScroll: true })
    this.#update(this.#fromPointer(event))
    this.thumbTarget.focus({ preventScroll: true })
  }

  #end() {
    if (this.value !== this.state.startValue) this.state.commits++
    this.#render()
  }

  #fromPointer(event) {
    const rect = this.rootTarget.getBoundingClientRect()
    const ratio = (event.clientX - rect.left) / rect.width
    return this.minValue + ratio * (this.maxValue - this.minValue)
  }

  #update(raw) {
    const snapped = Math.round((Math.min(Math.max(raw, this.minValue), this.maxValue) - this.minValue) / this.stepValue) * this.stepValue + this.minValue
    const value = Math.min(Math.max(snapped, this.minValue), this.maxValue)
    if (value === this.value) return
    this.value = value
    this.thumbTarget.setAttribute("aria-valuenow", String(value))
    this.#render()
  }

  #count = (event) => {
    this.state.moves++
    if (event.target.hasPointerCapture(event.pointerId)) this.state.captured++
    this.#render()
  }

  #render() {
    this.readoutTarget.textContent = `value=${this.value} commits=${this.state.commits} moves=${this.state.moves} captured=${this.state.captured}`
  }
}
