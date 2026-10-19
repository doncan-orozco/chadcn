// Parity probe for shadcn/primitives/positioner (scenario _primitives-positioner). Not a product controller.
// Root children: anchor, content. Options come from data-parity-options, the same JSON the React twin
// (react-shadcn-catalog/src/parity/primitives/positioner.tsx) reads.
import { Controller } from "@hotwired/stimulus"
import { positioner } from "shadcn/primitives/positioner"

const SVG = "http://www.w3.org/2000/svg"

export default class extends Controller {
  connect() {
    const { arrow, boundary, ...options } = JSON.parse(this.element.dataset.parityOptions || "{}")
    const [anchor, content] = this.element.children
    const arrowSpan = arrow ? this.buildArrow(content) : undefined
    const collisionBoundary = boundary ? document.querySelector(boundary) : undefined
    this.handle = positioner(anchor, content, { ...options, arrow: arrowSpan, ...(collisionBoundary && { collisionBoundary }) })
  }

  disconnect() {
    this.handle?.release()
  }

  // Same DOM as Radix PopperArrow + Arrow: span > svg[data-slot=arrow] > polygon.
  buildArrow(content) {
    const span = document.createElement("span")
    const svg = document.createElementNS(SVG, "svg")
    svg.setAttribute("data-slot", "arrow")
    svg.setAttribute("width", "10")
    svg.setAttribute("height", "5")
    svg.setAttribute("viewBox", "0 0 30 10")
    svg.setAttribute("preserveAspectRatio", "none")
    svg.style.display = "block"
    const polygon = document.createElementNS(SVG, "polygon")
    polygon.setAttribute("points", "0,0 30,0 15,10")
    svg.append(polygon)
    span.append(svg)
    content.append(span)
    return span
  }
}
