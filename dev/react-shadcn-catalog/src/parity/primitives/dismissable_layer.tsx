// Oracle for app/javascript/v2/primitives/dismissable_layer.js: raw @radix-ui/react-dismissable-layer.
// Templates are layers named by `data-name`; `open`/`close` actions take a `name` param.
import * as React from "react"
import { DismissableLayer } from "@radix-ui/react-dismissable-layer"
import { actionOf, flag, items, isTemplate, templateName, only, type El } from "./_overlay"

const C = "shadcn---probe-dismissable"

function DismissableProbe({ children, ...props }: Record<string, any>) {
  const [open, setOpen] = React.useState<string[]>([])
  const modal = flag(props, C, "modal")
  const preventEscape = flag(props, C, "prevent-escape")
  const preventOutside = flag(props, C, "prevent-outside")
  const close = (name: string) => setOpen((names) => names.filter((n) => n !== name))

  const onClick = (e: React.MouseEvent) => {
    const action = actionOf(e.target, C)
    if (!action) return
    const name = action.params.name
    if (action.method === "open") setOpen((names) => (names.includes(name) ? names : [...names, name]))
    if (action.method === "close") close(name)
  }

  return (
    <div {...props} onClick={onClick}>
      {items(children).map((node) => {
        if (!isTemplate(node)) return node
        const name = templateName(node)
        if (!open.includes(name)) return null
        return (
          <DismissableLayer
            key={node.key}
            asChild
            disableOutsidePointerEvents={modal}
            onEscapeKeyDown={(e) => preventEscape && e.preventDefault()}
            onPointerDownOutside={(e) => preventOutside && e.preventDefault()}
            onFocusOutside={(e) => preventOutside && e.preventDefault()}
            onDismiss={() => close(name)}
          >
            {only(node.props.children)}
          </DismissableLayer>
        )
      })}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-dismissable", Component: DismissableProbe }
