import { Controller } from "@hotwired/stimulus"

// Light / Dark / System. shadcn themes need only `.dark` on <html> (light is its absence), so this
// controller toggles that single class and mirrors the OS preference into it when the choice is "system".
// The choice persists in localStorage ("papyro-theme", same key as the legacy controller).
//
//   <div data-controller="shadcn--theme">
//     <button data-action="shadcn--theme#setLight">...</button>  setDark / setSystem / toggle
export default class extends Controller {
  static values = { current: { type: String, default: "system" } }

  #mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
  #systemListener = () => this.#apply()

  connect() {
    this.currentValue = localStorage.getItem("papyro-theme") || "system"
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
    if (theme === "system") localStorage.removeItem("papyro-theme")
    else localStorage.setItem("papyro-theme", theme)
    this.#apply()
    this.dispatch("changed", { detail: { theme } })
  }

  #apply() {
    const html = document.documentElement
    const dark = this.currentValue === "dark" || (this.currentValue === "system" && this.#mediaQuery.matches)
    html.classList.toggle("dark", dark)
    html.dataset.theme = this.currentValue
  }
}
