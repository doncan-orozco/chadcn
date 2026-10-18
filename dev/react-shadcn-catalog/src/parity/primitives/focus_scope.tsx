// Oracle for app/javascript/v2/primitives/focus_scope.js: raw @radix-ui/react-focus-scope.
import * as React from "react"
import { FocusScope } from "@radix-ui/react-focus-scope"
import { actionOf, flag, items, isTemplate, only, type El } from "./_overlay"

const C = "shadcn---probe-focus-scope"

function FocusScopeProbe({ children, ...props }: Record<string, any>) {
  const [open, setOpen] = React.useState(false)
  const onClick = (e: React.MouseEvent) => {
    const method = actionOf(e.target, C)?.method
    if (method === "open") setOpen(true)
    if (method === "close") setOpen(false)
  }
  return (
    <div {...props} onClick={onClick}>
      {items(children).map((node) =>
        isTemplate(node) ? (
          open && (
            <FocusScope
              key={node.key}
              asChild
              trapped={flag(props, C, "trapped")}
              loop={flag(props, C, "loop")}
              onMountAutoFocus={(e) => flag(props, C, "prevent-mount-focus") && e.preventDefault()}
              onUnmountAutoFocus={(e) => flag(props, C, "prevent-unmount-focus") && e.preventDefault()}
            >
              {only(node.props.children)}
            </FocusScope>
          )
        ) : (
          node
        ),
      )}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-focus-scope", Component: FocusScopeProbe }
