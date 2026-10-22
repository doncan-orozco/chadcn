// Oracle for app/javascript/v2/primitives/scroll_lock.js: raw react-remove-scroll, as Radix Dialog mounts it.
import * as React from "react"
import { RemoveScroll } from "react-remove-scroll"
import { Slot } from "@radix-ui/react-slot"
import { actionOf } from "./_overlay"

function ScrollLockProbe({ children, ...props }: Record<string, any>) {
  const [held, setHeld] = React.useState<string[]>([])
  const onClick = (e: React.MouseEvent) => {
    const action = actionOf(e.target, "chadcn---probe-scroll-lock")
    if (action?.method !== "toggle") return
    const name = action.params.name
    setHeld((names) => (names.includes(name) ? names.filter((n) => n !== name) : [...names, name]))
  }
  return (
    <div {...props} onClick={onClick}>
      {children}
      {held.map((name) => (
        <RemoveScroll key={name} as={Slot} allowPinchZoom>
          <span hidden />
        </RemoveScroll>
      ))}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "chadcn---probe-scroll-lock", Component: ScrollLockProbe }
