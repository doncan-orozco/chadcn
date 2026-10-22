import { Controller } from "@hotwired/stimulus"

// Parity probe for chadcn/primitives/toast_stack (dev/port/scenarios/sonner.json): a click on a descendant with data-parity-toast calls
// window.Toaster (the same call a page makes). Twin: react-shadcn-catalog/src/parity/primitives/toast_probe.tsx.
export default class extends Controller {
  connect() {
    this.onClick = (event) => {
      const holder = event.target.closest("[data-parity-toast]")
      if (holder && this.element.contains(holder)) this.run(JSON.parse(holder.getAttribute("data-parity-toast") || "{}"))
    }
    this.element.addEventListener("click", this.onClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
  }

  run(call) {
    const toast = window.Toaster
    if (call.method === "dismiss") return toast.dismiss(call.id)
    if (call.method === "promise") {
      const promise = new Promise((resolve, reject) => setTimeout(() => (call.outcome === "reject" ? reject(new Error("boom")) : resolve("ok")), call.delay ?? 300))
      return toast.promise(promise, { ...(call.data ?? {}), ...(call.messages ?? {}) })
    }
    if (call.method === "message") return toast(call.message ?? "", call.data)
    return toast[call.method](call.message, call.data)
  }
}
