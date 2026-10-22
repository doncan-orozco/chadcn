import { Controller } from "@hotwired/stimulus"
import { ITEM_ATTR, items, textValue } from "chadcn/primitives/collection"

// Parity probe for chadcn/primitives/collection (scenarios _primitives-collection). Buttons by data-slot: read (writes the ordered
// items to out / out-all), prepend / append (add an item to the list), toggle (flips data-disabled on item-b).
export default class extends Controller {
  #front = 0
  #end = 0

  connect() {
    this.element.addEventListener("click", this.#click)
  }

  disconnect() {
    this.element.removeEventListener("click", this.#click)
  }

  #click = (event) => {
    const slot = event.target.closest("[data-slot]")?.dataset.slot
    if (slot === "read") this.#read()
    if (slot === "prepend") this.#add("front", "afterbegin", ++this.#front)
    if (slot === "append") this.#add("end", "beforeend", ++this.#end)
    if (slot === "toggle") this.#slot("item-b").toggleAttribute("data-disabled")
  }

  #slot(name) {
    return this.element.querySelector(`[data-slot=${name}]`)
  }

  #read() {
    this.#slot("out").textContent = items(this.element).map(textValue).join(",")
    this.#slot("out-all").textContent = items(this.element, { includeDisabled: true }).map(textValue).join(",")
  }

  #add(kind, position, n) {
    const label = `${kind === "front" ? "Front" : "End"} ${n}`
    this.#slot("list").insertAdjacentHTML(position, `<span data-slot="item-${kind}-${n}" ${ITEM_ATTR}="">${label}</span>`)
  }
}
