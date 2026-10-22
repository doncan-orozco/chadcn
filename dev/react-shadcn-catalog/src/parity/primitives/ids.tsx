// React twin of app/javascript/v2/primitives/ids.js: the RAW @radix-ui/react-id useId (deterministic id first).
// Tree contract: _div[data-controller="chadcn---probe-ids"] containing a trigger [data-slot=trigger] and a panel [data-slot=panel]
// (optionally with a server `id`). The trigger gets aria-controls = the panel id, and data-id-source = server | generated.
import * as React from "react"
import { useId } from "@radix-ui/react-id"

type AnyProps = Record<string, any>

function IdsProbe({ children, ...props }: AnyProps) {
  let panelProps: AnyProps = {}
  React.Children.forEach(children, (c) => { if (React.isValidElement(c) && (c.props as AnyProps)["data-slot"] === "panel") panelProps = c.props as AnyProps })
  const id = useId(panelProps.id)
  const source = panelProps.id ? (id === panelProps.id ? "server" : "CHANGED") : id.startsWith("radix-") ? "generated" : "EMPTY"
  const wire = (node: React.ReactNode): React.ReactNode => {
    if (!React.isValidElement(node)) return node
    const p = node.props as AnyProps
    if (p["data-slot"] === "trigger") return React.cloneElement(node, { "aria-controls": id, "data-id-source": source })
    if (p["data-slot"] === "panel") return React.cloneElement(node, { id })
    return node
  }
  return <div {...props}>{React.Children.map(children, wire)}</div>
}

export const probe = { controller: "chadcn---probe-ids", Component: IdsProbe }
