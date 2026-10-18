// Oracle for app/javascript/v2/primitives/focus_guards.js: raw @radix-ui/react-focus-guards (one <FocusGuards> per holder).
import * as React from "react"
import { FocusGuards } from "@radix-ui/react-focus-guards"
import { actionOf } from "./_overlay"

function FocusGuardsProbe({ children, ...props }: Record<string, any>) {
  const [held, setHeld] = React.useState<string[]>([])
  const onClick = (e: React.MouseEvent) => {
    const action = actionOf(e.target, "shadcn---probe-focus-guards")
    if (action?.method !== "toggle") return
    const name = action.params.name
    setHeld((names) => (names.includes(name) ? names.filter((n) => n !== name) : [...names, name]))
  }
  return (
    <div {...props} onClick={onClick}>
      {children}
      {held.map((name) => (
        <FocusGuards key={name} />
      ))}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-focus-guards", Component: FocusGuardsProbe }
