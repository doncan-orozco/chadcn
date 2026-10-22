import { Controller } from "@hotwired/stimulus"

// Light / Dark / System. shadcn themes need only `.dark` on <html> (light is its absence), so this
// controller toggles that single class and mirrors the OS preference into it when the choice is "system".
// The choice persists in localStorage under `storageKey` (default "shadcn-theme"); a pre-paint script that avoids the flash of the
// wrong theme has to read the same key and apply `.dark` and `data-theme` on <html> the way #apply does. The key is read once at connect and
// must stay static while the controller is connected. Storage that throws (private windows, blocked site data) degrades to the system
// preference. disconnect leaves `.dark` and `data-theme` in place on purpose (a persisted page-wide choice; it keeps Turbo snapshots right).
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

  connect() {
    this.currentValue = this.#read()
    this.#apply()
    this.#mediaQuery.addEventListener("change", this.#systemListener)
  }

  disconnect() {
    this.#mediaQuery.removeEventListener("change", this.#systemListener)
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
    this.dispatch("changed", { detail: { theme } })
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
