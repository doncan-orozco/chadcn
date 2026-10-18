// Oracle for app/javascript/v2/primitives/portal.js: raw @radix-ui/react-portal (asChild, as the Radix overlays use it).
import * as React from "react"
import { Portal } from "@radix-ui/react-portal"
import { actionOf, items } from "./_overlay"

function PortalProbe({ children, ...props }: Record<string, any>) {
  const [on, setOn] = React.useState(true)
  const [container, setContainer] = React.useState<HTMLElement | null>(null)
  const selector: string | undefined = props["data-shadcn---probe-portal-container-value"]
  React.useEffect(() => setContainer(selector ? document.querySelector<HTMLElement>(selector) : null), [selector])

  return (
    <div {...props} onClick={(e) => actionOf(e.target, "shadcn---probe-portal")?.method === "toggle" && setOn((v) => !v)}>
      {items(children).map((node) =>
        React.isValidElement<Record<string, any>>(node) && node.props["data-shadcn---probe-portal-target"] === "item" && on ? (
          <Portal key={node.key} asChild container={container}>
            {node}
          </Portal>
        ) : (
          node
        ),
      )}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-portal", Component: PortalProbe }
