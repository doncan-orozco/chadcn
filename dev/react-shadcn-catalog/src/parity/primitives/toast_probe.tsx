// Oracle for app/javascript/chadcn/primitives/toast_stack.js: RAW sonner (`toast`) driven by clicks on the scenario tree. sonner's toast() is a
// module function, so a static tree cannot call it; this twin gives the tree buttons that do. Rendered by Harness.tsx for
// `_div[data-controller="chadcn---probe-toast"]`; the Phlex side drives the same tree with
// dev/dummy/app/javascript/controllers/chadcn/_probe_toast_controller.js (window.Toaster).
//   Any descendant with data-parity-toast = JSON { method, message?, data?, id? }: a click calls toast[method](message, data) (method "message"
//   = toast(); "dismiss" takes id; "promise" takes { delay, outcome: "resolve"|"reject", messages: { loading, success, error } }).
import * as React from "react"
import { toast } from "sonner"

type Call = { method: string; message?: string; data?: Record<string, unknown>; id?: string; delay?: number; outcome?: string; messages?: Record<string, string> }

function run(call: Call) {
  const api = toast as unknown as Record<string, (...args: unknown[]) => unknown>
  if (call.method === "dismiss") return toast.dismiss(call.id)
  if (call.method === "promise") {
    const promise = new Promise((resolve, reject) => setTimeout(() => (call.outcome === "reject" ? reject(new Error("boom")) : resolve("ok")), call.delay ?? 300))
    return toast.promise(promise, { ...(call.data ?? {}), ...(call.messages ?? {}) } as never)
  }
  if (call.method === "message") return toast(call.message ?? "", call.data)
  return api[call.method](call.message, call.data)
}

function ToastProbe({ children, ...props }: Record<string, unknown> & { children?: React.ReactNode }) {
  return (
    <div
      {...props}
      onClick={(event) => {
        const holder = (event.target as HTMLElement).closest("[data-parity-toast]")
        if (holder) run(JSON.parse(holder.getAttribute("data-parity-toast") ?? "{}"))
      }}
    >
      {children}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "chadcn---probe-toast", Component: ToastProbe }
