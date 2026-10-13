import { Controller } from "@hotwired/stimulus"
import { rovingFocus } from "shadcn/primitives/roving_focus"
import { presence } from "shadcn/primitives/presence"

// Radix Tabs. Spec: docs/shadcn-port/specs/tabs.md (Behavior).
//
// One controller on the root. Inactive panels ship their body in an inert <template> (React does not mount them);
// connect() takes it over so the DOM equals Radix: an inactive panel is an empty hidden element, an inactive as_child
// panel is only a comment anchor. Every activation mounts a FRESH clone of the pristine body.
export default class extends Controller {
  static values = {
    value: String,
    controlled: Boolean,
    activationMode: { type: String, default: "automatic" },
    orientation: { type: String, default: "horizontal" },
    dir: String
  }
  static targets = ["list", "trigger", "content", "deferred"]

  connect() {
    this.current = this.valueValue
    this.animationGuard = true
    this.triggers = this.triggerTargets.map((el) => ({ el, value: el.getAttribute("data-shadcn--tabs-item-value") }))
    this.panels = this.#buildPanels()
    const list = this.hasListTarget ? this.listTarget : null
    this.roving = list && rovingFocus(list, {
      orientation: this.orientationValue,
      loop: list.getAttribute("data-shadcn--tabs-loop-value") !== "false",
      dir: this.dirValue,
      isActive: (el) => el.dataset.state === "active"
    })
    this.ready = true
  }

  disconnect() {
    this.ready = false
    this.roving?.release()
    this.panels?.forEach((panel) => this.#restore(panel))
    this.panels = []
  }

  valueValueChanged() {
    if (this.ready && this.controlledValue) this.#apply(this.valueValue)
  }

  // --- selection requests ---------------------------------------------------------------------------------------------

  mousedown(event) {
    if (event.defaultPrevented) return
    const trigger = event.currentTarget
    if (!trigger.disabled && event.button === 0 && event.ctrlKey === false) {
      trigger.focus()
      this.#request(this.#valueOf(trigger))
    } else {
      event.preventDefault()
      this.#keepTabStop()
    }
  }

  // Radix composes the roving mousedown after ours, so a prevented press leaves the tab stop alone. The roving
  // primitive listens on the list itself: undo its tab stop change once the event bubbles past it.
  #keepTabStop() {
    const previous = this.roving?.currentTabStop() ?? null
    this.listTarget.addEventListener("mousedown", () => this.roving.setCurrentTabStop(previous), { once: true })
  }

  keydown(event) {
    if (event.defaultPrevented) return
    const trigger = event.currentTarget
    if ((event.key === " " || event.key === "Enter") && event.target === trigger && !trigger.disabled) {
      this.#request(this.#valueOf(trigger))
    }
  }

  focus(event) {
    if (event.defaultPrevented) return
    const trigger = event.currentTarget
    const selected = this.current === this.#valueOf(trigger)
    if (!selected && !trigger.disabled && this.activationModeValue !== "manual") this.#request(this.#valueOf(trigger))
  }

  #valueOf(trigger) {
    return trigger.getAttribute("data-shadcn--tabs-item-value")
  }

  // Controlled: dispatch only. Uncontrolled: update the DOM, then dispatch once per actual change.
  #request(value) {
    if (this.controlledValue) {
      if (value !== this.current) this.dispatch("value-change", { detail: { value }, cancelable: false })
      return
    }
    if (value === this.current) return
    this.#apply(value)
    this.dispatch("value-change", { detail: { value }, cancelable: false })
  }

  #apply(value) {
    this.current = value
    this.#releaseAnimationGuard()
    this.triggers.forEach(({ el, value: own }) => {
      const selected = own === value
      el.setAttribute("aria-selected", String(selected))
      el.dataset.state = selected ? "active" : "inactive"
    })
    this.panels.forEach((panel) => this.#setPanel(panel, panel.value === value))
  }

  // Radix drops the animation-duration: 0s guard on the first re-render of the panel selected at mount.
  #releaseAnimationGuard() {
    if (!this.animationGuard) return
    this.animationGuard = false
    this.panels.forEach(({ el }) => {
      if (el?.style.animationDuration) el.style.removeProperty("animation-duration")
    })
  }

  // --- panels ----------------------------------------------------------------------------------------------------------

  #buildPanels() {
    const inner = this.contentTargets.map((el) => this.#panel(el))
    const deferred = this.deferredTargets.filter((tpl) => tpl.hasAttribute("data-shadcn--tabs-as-child")).map((tpl) => this.#detached(tpl))
    return [...inner, ...deferred]
  }

  #panel(el) {
    const forceMount = el.getAttribute("data-shadcn--tabs-force-mount") === "true"
    const asChild = el.hasAttribute("data-shadcn--tabs-as-child")
    const panel = { value: el.getAttribute("data-shadcn--tabs-item-value"), forceMount, asChild, el, mounted: true }
    if (asChild) {
      panel.body = this.#cloneOf(el)
      panel.anchor = document.createComment("")
      el.before(panel.anchor)
    } else {
      const template = el.querySelector(":scope > template[data-shadcn--tabs-target~=deferred]")
      template?.remove()
      panel.body = template || this.#bodyOf(el)
      panel.mounted = !template
    }
    panel.presence = this.#presence(panel)
    return panel
  }

  #detached(template) {
    const panel = { value: template.getAttribute("data-shadcn--tabs-item-value"), forceMount: false, asChild: true, el: null, mounted: false, body: template }
    panel.anchor = document.createComment("")
    template.replaceWith(panel.anchor)
    return panel
  }

  #bodyOf(el) {
    const body = this.#template()
    body.content.append(...[...el.childNodes].map((node) => node.cloneNode(true)))
    return body
  }

  #cloneOf(el) {
    const body = this.#template()
    const clone = el.cloneNode(true)
    clone.style.removeProperty("animation-duration")
    body.content.append(clone)
    return body
  }

  #template() {
    const template = document.createElement("template")
    template.setAttribute("data-shadcn--tabs-target", "deferred")
    return template
  }

  #presence(panel) {
    if (!panel.el || panel.forceMount) return null
    return presence(panel.el, { onExited: () => this.#unmount(panel) })
  }

  #setPanel(panel, active) {
    const isActive = panel.el?.dataset.state === "active"
    if (active === isActive) return
    if (panel.forceMount) {
      panel.el.dataset.state = active ? "active" : "inactive"
      return
    }
    if (active) return this.#mount(panel)
    panel.el.dataset.state = "inactive"
    panel.presence.exit()
  }

  #mount(panel) {
    if (panel.asChild) {
      const node = panel.body.content.cloneNode(true)
      panel.el = node.firstElementChild
      panel.anchor.after(node)
      panel.presence = this.#presence(panel)
      panel.mounted = true
      return
    }
    panel.el.dataset.state = "active"
    panel.el.hidden = false
    panel.presence.enter()
    if (!panel.mounted) {
      panel.el.append(panel.body.content.cloneNode(true))
      panel.mounted = true
    }
  }

  #unmount(panel) {
    if (!panel.mounted || panel.el?.dataset.state === "active") return
    panel.presence?.release()
    panel.mounted = false
    if (panel.asChild) {
      panel.el.remove()
      panel.el = null
      return
    }
    panel.el.hidden = true
    panel.el.replaceChildren()
  }

  // Back to the server shape so a Turbo cache snapshot reconnects to equivalent markup.
  #restore(panel) {
    panel.presence?.release()
    if (panel.asChild) {
      if (!panel.el) {
        panel.body.setAttribute("data-shadcn--tabs-item-value", panel.value)
        panel.body.setAttribute("data-shadcn--tabs-as-child", "true")
        panel.anchor.replaceWith(panel.body)
      } else panel.anchor.remove()
      return
    }
    if (!panel.mounted) panel.el.replaceChildren(panel.body)
  }
}
