import { Controller } from "@hotwired/stimulus"

const THEMES = Object.freeze(["light", "dark", "system"])

// Light / Dark / System. shadcn themes need only `.dark` on <html> (light is its absence), so this
// controller toggles that single class and mirrors the OS preference into it when the choice is "system".
// The choice persists in localStorage under `storageKey` (default "shadcn-theme"); a pre-paint script that avoids the flash of the
// wrong theme has to read the same key and apply `.dark` and `data-theme` on <html> the way #apply does. The key is read once at connect and
// must stay static while the controller is connected. Storage that throws (private windows, blocked site data) degrades to the system
// preference. disconnect leaves `.dark` and `data-theme` in place on purpose (a persisted page-wide choice; it keeps Turbo snapshots right).
// Instances with the same key follow each other's `chadcn--theme:changed` (an event without a key makes them re-read storage) and the
// `storage` event of other tabs; adopting a choice never dispatches again.
//
//   <div data-controller="chadcn--theme" data-chadcn--theme-storage-key-value="my-app-theme">
//     <button data-action="chadcn--theme#setLight">...</button>  setDark / setSystem / toggle
export default class extends Controller {
  static values = {
    current: { type: String, default: "system" },
    storageKey: { type: String, default: "shadcn-theme" }
  }

  // An empty attribute must not turn into the "" key shared by everything.
  get #key() { return this.storageKeyValue || "shadcn-theme" }

  #mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
  #systemListener = () => this.#apply()

  // Another instance's choice: its own detail when the key matches, a re-read when a host dispatches the event without a key.
  #changedListener = (event) => {
    if (event.target === this.element) return
    const { theme, storageKey } = event.detail ?? {}
    if (storageKey === undefined) return this.#follow(this.#read())
    if (storageKey !== this.#key) return
    this.#follow(THEMES.includes(theme) ? theme : this.#read())
  }

  // Another tab or page of the origin changed (or cleared) the stored choice.
  #storageListener = (event) => {
    if (event.storageArea !== localStorage) return
    if (event.key === null || event.key === this.#key) this.#follow(this.#read())
  }

  connect() {
    this.currentValue = this.#read()
    this.#apply()
    this.#mediaQuery.addEventListener("change", this.#systemListener)
    window.addEventListener("chadcn--theme:changed", this.#changedListener)
    window.addEventListener("storage", this.#storageListener)
  }

  disconnect() {
    this.#mediaQuery.removeEventListener("change", this.#systemListener)
    window.removeEventListener("chadcn--theme:changed", this.#changedListener)
    window.removeEventListener("storage", this.#storageListener)
  }

  // Cycle: system -> light -> dark -> system
  toggle() {
    const cycle = { system: "light", light: "dark", dark: "system" }
    this.#set(cycle[this.currentValue] ?? "system")
  }

  setLight() { this.#set("light") }
  setDark() { this.#set("dark") }
  setSystem() { this.#set("system") }

  #set(theme) {
    this.currentValue = theme
    this.#write(theme)
    this.#apply()
    this.dispatch("changed", { detail: { theme, storageKey: this.#key } })
  }

  // Adopt a choice made elsewhere: apply it, never dispatch (one user action is one `changed` event page-wide).
  #follow(theme) {
    this.currentValue = theme
    this.#apply()
  }

  // The stored choice when it is "light" or "dark"; anything else (nothing stored, a stale value, blocked storage) is "system".
  #read() {
    try {
      const stored = localStorage.getItem(this.#key)
      return stored === "light" || stored === "dark" ? stored : "system"
    } catch {
      return "system"
    }
  }

  #write(theme) {
    try {
      if (theme === "system") localStorage.removeItem(this.#key)
      else localStorage.setItem(this.#key, theme)
    } catch {
      // storage unavailable: the choice applies to this page only
    }
  }

  #apply() {
    const html = document.documentElement
    const dark = this.currentValue === "dark" || (this.currentValue === "system" && this.#mediaQuery.matches)
    html.classList.toggle("dark", dark)
    html.dataset.theme = this.currentValue
  }
}
