// Oracle for app/javascript/v2/primitives/template_mount.js: conditional rendering (in place, or portaled to <body>).
import * as React from "react"
import { createPortal } from "react-dom"
import { actionOf, items, isTemplate } from "./_overlay"

function TemplateMountProbe({ children, ...props }: Record<string, any>) {
  const [open, setOpen] = React.useState(false)
  const into = props["data-shadcn---probe-template-mount-into-value"] === "body" ? "body" : "after"
  return (
    <div {...props} onClick={(e) => actionOf(e.target, "shadcn---probe-template-mount")?.method === "toggle" && setOpen((v) => !v)}>
      {items(children).map((node) => {
        if (!isTemplate(node)) return node
        if (!open) return null
        return into === "body" ? createPortal(node.props.children, document.body, String(node.key)) : <React.Fragment key={node.key}>{node.props.children}</React.Fragment>
      })}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-template-mount", Component: TemplateMountProbe }
