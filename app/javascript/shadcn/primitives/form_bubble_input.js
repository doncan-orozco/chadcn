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

export class FormBubbleInput {
  static isFormControl(control, form) {
    return !!form || !!control.closest("form")
  }

  // options: type ("checkbox"|"radio"|"select"), name, value, checked, indeterminate, required, disabled, form,
  //          autocomplete, options ([{ value, label, disabled }] for select), onReset (function)
  constructor(control, options = {}) {
    this.control = control
    this.type = options.type || "checkbox"
    this.state = { value: this.type === "checkbox" ? "on" : "", checked: false, indeterminate: false, ...options }
    this.checked = this.#boolean(this.state.checked, this.state.indeterminate)
    this.initial = this.state.checked
    this.input = null
    this.#resizeObserver = null
    this.#onReset = options.onReset
    if (FormBubbleInput.isFormControl(control, this.state.form)) this.#mount()
  }

  get present() { return !!this.input }

  // changes: any subset of the constructor options. context: { userInteraction, propagationStopped }.
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

  release() {
    this.#resizeObserver?.disconnect()
    this.#form()?.removeEventListener("reset", this.#resetListener)
    this.input?.remove()
    this.input = null
  }

  #resizeObserver
  #onReset
  #resetListener = () => this.#onReset?.()

  #mount() {
    const tagName = this.type === "select" ? "select" : "input"
    // Server-rendered bubble input directly after the control is adopted instead of duplicated.
    const next = this.control.nextElementSibling
    this.input = next?.tagName.toLowerCase() === tagName && next.getAttribute("aria-hidden") === "true" ? next : this.#create(tagName)
    if (this.type === "select") this.#renderOptions()
    this.#applyAttributes()
    this.#applyStyle()
    this.input.checked = this.checked
    if (this.type === "checkbox") this.input.indeterminate = this.state.indeterminate === true
    if (this.type !== "select") this.input.defaultChecked = this.checked
    this.#observeSize()
    this.#form()?.addEventListener("reset", this.#resetListener)
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
    let frame = 0
    this.#resizeObserver = new ResizeObserver((entries) => {
      const entry = entries[0]
      if (!entry) return
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
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
