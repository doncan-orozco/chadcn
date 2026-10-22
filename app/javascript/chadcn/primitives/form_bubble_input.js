// Hidden native control kept in sync with a custom checkbox / switch / radio / select so forms submit and the
// native events reach the form, exactly like Radix's internal BubbleInput (react-checkbox, react-switch,
// react-radio-group, react-select). Replaces: internal BubbleInput.
//
// Known divergences: none observable in the DOM. React-only detail NOT ported: Radix also stops the synthetic click of
// a programmatic sync inside the React tree (shouldStopClickPropagationRef); native listeners on the form see the
// click either way, as they do in React (the React root sits above the form).
//
// Usage:
//   const bubble = new FormBubbleInput(buttonEl, { type: "checkbox", name: "terms", value: "on", checked: false })
//   bubble.sync({ checked: true }, { userInteraction: true, propagationStopped: event.cancelBubble })
//   bubble.release()
//
// Radix contract (verified against the installed packages):
//   - rendered only when the control is inside a <form> (closest("form")) or has a `form` attribute;
//   - sibling placed immediately AFTER the control; aria-hidden="true", tabindex="-1";
//   - checkbox/radio/switch: `<input type=checkbox|radio>`, position:absolute, pointer-events:none, opacity:0,
//     margin:0, transform:translateX(-100%), width/height = the control's border box (kept in sync);
//   - select: `<select>` with the VisuallyHidden styles, `<option>`s mirroring the items;
//   - a changed `checked` sets the native property through the prototype setter and dispatches a bubbling `click`
//     (checkbox/radio/switch); a changed select value dispatches a bubbling `change`;
//   - the click does not bubble when the change came from the user and a consumer already stopped the control click;
//   - the form's `reset` event restores the initial state (onReset callback).

const VISUALLY_HIDDEN = {
  position: "absolute", border: "0", width: "1px", height: "1px", padding: "0", margin: "-1px",
  overflow: "hidden", clip: "rect(0px, 0px, 0px, 0px)", whiteSpace: "nowrap", wordWrap: "normal"
}

/**
 * Hidden native input/select kept in sync with a custom checkbox, switch, radio or select so forms submit and native events bubble.
 *
 * Public surface: the constructor, isFormControl, present, input, sync(), release(). The instance fields control, type,
 * state, checked, initial, selectValue and optionsSignature are internal (@api private).
 * @example
 * const bubble = new FormBubbleInput(buttonEl, { type: "checkbox", name: "terms", value: "on", checked: false })
 * bubble.sync({ checked: true }, { userInteraction: true, propagationStopped: event.cancelBubble })
 * bubble.release()
 */
export class FormBubbleInput {
  /**
   * Whether a control needs a bubble input: it is inside a <form> or has a `form` attribute.
   * @param {Element} control
   * @param {string} [form] The control's `form` attribute.
   * @returns {boolean}
   */
  static isFormControl(control, form) {
    return !!form || !!control.closest("form")
  }

  /**
   * @param {HTMLElement} control The custom control; the bubble input is placed right after it.
   * @param {object} [options]
   * @param {"checkbox" | "radio" | "select"} [options.type="checkbox"] A switch uses type "checkbox".
   * @param {string} [options.name]
   * @param {string} [options.value]
   * @param {boolean} [options.checked]
   * @param {boolean} [options.indeterminate]
   * @param {boolean} [options.required]
   * @param {boolean} [options.disabled]
   * @param {string} [options.form] Id of the owning form.
   * @param {string} [options.autocomplete]
   * @param {{ value: string, label?: string, disabled?: boolean }[]} [options.options] Select options.
   * @param {() => void} [options.onReset] Runs when the form is reset.
   */
  constructor(control, options = {}) {
    /** @api private */
    this.control = control
    /** @api private */
    this.type = options.type || "checkbox"
    /** @api private */
    this.state = { value: this.type === "checkbox" ? "on" : "", checked: false, indeterminate: false, ...options }
    /** @api private */
    this.checked = this.#boolean(this.state.checked, this.state.indeterminate)
    /** @api private */
    this.initial = this.state.checked
    /**
     * The mounted native <input>/<select> (null outside a form and after release()). Read-only for consumers
     * (e.g. select_controller.js listens to its change).
     * @type {HTMLInputElement | HTMLSelectElement | null}
     */
    this.input = null
    this.#resizeObserver = null
    this.#onReset = options.onReset
    if (FormBubbleInput.isFormControl(control, this.state.form)) this.#mount()
  }

  /** Whether a bubble input is mounted. @type {boolean} */
  get present() { return !!this.input }

  /**
   * Applies changed options to the native input; dispatches a bubbling `click` (checkbox/radio) or `change` (select) when the value changed.
   * @param {object} [changes] Any subset of the constructor options.
   * @param {object} [context]
   * @param {boolean} [context.userInteraction=false] The change comes from the user.
   * @param {boolean} [context.propagationStopped=false] A consumer stopped the control click. The dispatched click does not
   *   bubble only when `userInteraction && propagationStopped`; otherwise it always bubbles.
   */
  sync(changes = {}, { userInteraction = false, propagationStopped = false } = {}) {
    Object.assign(this.state, changes)
    if (!this.input) return
    this.#applyAttributes()
    if (this.type === "select") return this.#syncSelect()

    const checked = this.#boolean(this.state.checked, this.state.indeterminate)
    if (checked === this.checked && !("indeterminate" in changes)) return
    const changed = checked !== this.checked
    this.checked = checked
    if (this.type === "checkbox") this.input.indeterminate = this.state.indeterminate === true
    this.#setNative("checked", checked)
    if (changed) this.input.dispatchEvent(new Event("click", { bubbles: !(userInteraction && propagationStopped) }))
  }

  /**
   * Removes the resize observer, the pending frame and the form reset listener, and the input it created; safe to call twice.
   * A server-rendered input it adopted stays in the DOM (it carries the name, required and form of the control), so a
   * reconnect adopts it again.
   */
  release() {
    this.#resizeObserver?.disconnect()
    this.#resizeObserver = null
    cancelAnimationFrame(this.#frame)
    this.#frame = 0
    this.#boundForm?.removeEventListener("reset", this.#resetListener)
    this.#boundForm = null
    if (!this.#adopted) this.input?.remove()
    this.#adopted = false
    this.input = null
  }

  #resizeObserver
  #frame = 0
  #adopted = false
  #boundForm = null
  #onReset
  #resetListener = () => this.#onReset?.()

  #mount() {
    const tagName = this.type === "select" ? "select" : "input"
    // Server-rendered bubble input directly after the control is adopted instead of duplicated.
    const next = this.control.nextElementSibling
    this.#adopted = next?.tagName.toLowerCase() === tagName && next.getAttribute("aria-hidden") === "true"
    this.input = this.#adopted ? next : this.#create(tagName)
    if (this.type === "select") this.#renderOptions()
    this.#applyAttributes()
    this.#applyStyle()
    this.input.checked = this.checked
    if (this.type === "checkbox") this.input.indeterminate = this.state.indeterminate === true
    if (this.type !== "select") this.input.defaultChecked = this.checked
    this.#observeSize()
    this.#boundForm = this.#form()
    this.#boundForm?.addEventListener("reset", this.#resetListener)
  }

  #create(tagName) {
    const input = document.createElement(tagName)
    if (tagName === "input") input.type = this.type
    this.control.after(input)
    return input
  }

  #applyAttributes() {
    const { name, value, required, disabled, form, autocomplete } = this.state
    this.input.setAttribute("aria-hidden", "true")
    this.input.tabIndex = -1
    this.#attribute("name", name)
    this.#attribute("form", form)
    this.#attribute("autocomplete", autocomplete)
    if (this.type !== "select") this.#attribute("value", value)
    this.input.required = !!required
    this.input.disabled = !!disabled
  }

  #attribute(name, value) {
    if (value == null || value === false) this.input.removeAttribute(name)
    else this.input.setAttribute(name, value)
  }

  #applyStyle() {
    const style = this.input.style
    if (this.type === "select") return Object.assign(style, VISUALLY_HIDDEN)
    Object.assign(style, { position: "absolute", pointerEvents: "none", opacity: "0", margin: "0", transform: "translateX(-100%)" })
    this.#size(this.control.offsetWidth, this.control.offsetHeight)
  }

  #size(width, height) {
    if (this.type === "select") return
    this.input.style.width = `${width}px`
    this.input.style.height = `${height}px`
  }

  // Radix useSize: border box of the control, updated on the next frame after a resize.
  #observeSize() {
    if (this.type === "select" || typeof ResizeObserver === "undefined") return
    this.#resizeObserver = new ResizeObserver((entries) => {
      const entry = entries[0]
      if (!entry) return
      cancelAnimationFrame(this.#frame)
      this.#frame = requestAnimationFrame(() => {
        if (!this.input) return
        const box = [].concat(entry.borderBoxSize)[0]
        this.#size(box ? box.inlineSize : this.control.offsetWidth, box ? box.blockSize : this.control.offsetHeight)
      })
    })
    this.#resizeObserver.observe(this.control, { box: "border-box" })
  }

  // select: the Radix change event fires when the value differs from the previous one.
  #syncSelect() {
    const value = this.state.value ?? ""
    this.#renderOptions()
    if (this.selectValue === value) return
    /** @api private */
    this.selectValue = value
    this.#setNative("value", value, HTMLSelectElement.prototype)
    this.input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #renderOptions() {
    const { options = [], value } = this.state
    const current = value ?? ""
    const hasEmpty = options.some((option) => (option.value ?? "") === "")
    const items = (current === "" && !hasEmpty ? [{ value: "" }] : []).concat(options)
    const signature = JSON.stringify(items)
    if (this.optionsSignature === signature) return
    /** @api private */
    this.optionsSignature = signature
    this.input.replaceChildren(...items.map(({ value: v, label, disabled }) => {
      const option = new Option(label ?? "", v ?? "")
      option.disabled = !!disabled
      return option
    }))
    this.input.value = current
    this.selectValue = this.selectValue ?? current
  }

  // React writes through the prototype setter so its own value tracker never swallows the event; keep the same path.
  #setNative(property, value, prototype = HTMLInputElement.prototype) {
    Object.getOwnPropertyDescriptor(prototype, property).set.call(this.input, value)
  }

  #boolean(checked, indeterminate) {
    return indeterminate === true ? false : !!checked
  }

  #form() {
    return this.state.form ? this.control.ownerDocument.getElementById(this.state.form) : this.control.closest("form")
  }
}
