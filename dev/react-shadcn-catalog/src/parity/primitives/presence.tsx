// Oracle for app/javascript/v2/primitives/presence.js (+ template_mount "after"): raw @radix-ui/react-presence.
import * as React from "react"
import { Presence } from "@radix-ui/react-presence"
import { actionOf, flag, items, isTemplate, only, type El } from "./_overlay"

function PresenceProbe({ children, ...props }: Record<string, any>) {
  const [open, setOpen] = React.useState(flag(props, "shadcn---probe-presence", "open"))
  return (
    <div {...props} onClick={(e) => actionOf(e.target, "shadcn---probe-presence")?.method === "toggle" && setOpen((v) => !v)}>
      {items(children).map((node) =>
        isTemplate(node) ? (
          <Presence key={node.key} present={open}>
            {React.cloneElement(only(node.props.children), { "data-state": open ? "open" : "closed" })}
          </Presence>
        ) : (
          node
        ),
      )}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-presence", Component: PresenceProbe }
