import { Controller } from "@hotwired/stimulus"

// Developer theme preview (Views::DesignSystem::ThemePanel). Writes the chosen preset's variables for the ACTIVE mode
// onto <html> as inline custom properties (so they beat `:root`/`.dark`), recomputes WCAG contrast per foreground/background
// pair with the same math as Chadcn::Theme, and copies a `theme:import`-compatible block. Nothing is persisted.
// Light/dark itself is the `chadcn--theme` controller; this one re-applies on its `changed` event (see data-action in the view).
export default class extends Controller {
  static targets = ["preset", "radius", "contrast", "status"]
  static values = { presets: Object, pairs: Array, current: String }

  #written = []

  connect() {
    this.presetTarget.value = this.currentValue
    this.#radius = getComputedStyle(document.documentElement).getPropertyValue("--radius").trim() || "0.625rem"
    this.radiusTarget.value = parseFloat(this.#radius) || 0.625
    this.refresh()
  }

  disconnect() {
    this.#clear()
  }

  applyPreset() {
    this.currentValue = this.presetTarget.value
    this.#radius = this.presetsValue[this.currentValue].root.radius ?? this.#radius
    this.radiusTarget.value = parseFloat(this.#radius)
    this.refresh()
  }

  applyRadius() {
    this.#radius = `${this.radiusTarget.value}rem`
    this.refresh()
  }

  // Also the handler of the `chadcn--theme:changed` event.
  refresh() {
    this.#clear()
    const vars = { ...this.#vars(), radius: this.#radius }
    const style = document.documentElement.style
    for (const [name, value] of Object.entries(vars)) {
      style.setProperty(`--${name}`, value)
      this.#written.push(`--${name}`)
    }
    this.#renderContrast(vars)
  }

  async copy() {
    const block = (selector, vars) => `${selector} {\n${Object.entries(vars).map(([k, v]) => `  --${k}: ${v};`).join("\n")}\n}\n`
    const preset = this.presetsValue[this.currentValue]
    const css = block(":root", { ...preset.root, radius: this.#radius }) + "\n" + block(".dark", preset.dark)
    await navigator.clipboard.writeText(css)
    this.statusTarget.textContent = "Copied. Paste into: bin/rails theme:import[path]"
  }

  get #dark() { return document.documentElement.classList.contains("dark") }

  #vars() {
    const preset = this.presetsValue[this.currentValue]
    return this.#dark ? preset.dark : preset.root
  }

  #clear() {
    this.#written.forEach((name) => document.documentElement.style.removeProperty(name))
    this.#written = []
  }

  #renderContrast(vars) {
    this.contrastTarget.replaceChildren(...this.pairsValue.map(([fg, bg]) => {
      const ratio = contrast(vars[fg], vars[bg])
      const li = document.createElement("li")
      const ok = ratio === null || ratio >= 4.5
      li.className = `flex justify-between rounded border px-2 py-1 ${ok ? "" : "border-destructive text-destructive"}`
      li.textContent = `${fg} / ${bg}: ${ratio === null ? "n/a" : `${ratio.toFixed(2)}:1`}`
      return li
    }))
  }

  #radius = "0.625rem"
}

// ---- color math (port of Chadcn::Theme.contrast) ----
const srgbToLinear = (v) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4)

function toLinearRgb(color) {
  const c = String(color ?? "").trim()
  let m = c.match(/^oklch\(\s*([\d.]+)(%?)\s+([\d.]+)\s+([\d.]+)(?:deg)?\s*\)$/)
  if (m) {
    const l = parseFloat(m[1]) / (m[2] ? 100 : 1)
    const a = parseFloat(m[3]) * Math.cos((parseFloat(m[4]) * Math.PI) / 180)
    const b = parseFloat(m[3]) * Math.sin((parseFloat(m[4]) * Math.PI) / 180)
    const l_ = (l + 0.3963377774 * a + 0.2158037573 * b) ** 3
    const m_ = (l - 0.1055613458 * a - 0.0638541728 * b) ** 3
    const s_ = (l - 0.0894841775 * a - 1.291485548 * b) ** 3
    return [
      4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
      -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
      -0.0041960863 * l_ - 0.7034186147 * m_ + 1.707614701 * s_,
    ].map((v) => Math.min(1, Math.max(0, v)))
  }
  m = c.match(/^hsl\(\s*([\d.]+)(?:deg)?\s+([\d.]+)%\s+([\d.]+)%\s*\)$/)
  if (m) {
    const h = parseFloat(m[1]), s = parseFloat(m[2]) / 100, l = parseFloat(m[3]) / 100
    const k = (n) => (n + h / 30) % 12
    const f = (n) => l - s * Math.min(l, 1 - l) * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1))
    return [f(0), f(8), f(4)].map(srgbToLinear)
  }
  m = c.match(/^#([\da-f]{2})([\da-f]{2})([\da-f]{2})$/i)
  if (m) return m.slice(1).map((h) => srgbToLinear(parseInt(h, 16) / 255))
  return null
}

function luminance(color) {
  const rgb = toLinearRgb(color)
  return rgb ? 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2] : null
}

function contrast(fg, bg) {
  const l1 = luminance(fg), l2 = luminance(bg)
  if (l1 === null || l2 === null) return null
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)
}
