// Oracle for app/javascript/v2/primitives/hide_others.js: the `aria-hidden` package, as Radix modal content uses it.
// Templates are named nodes (`data-name`), mounted `data-into="body"` or in place; `data-auto="true"` mounts at load.
// Names starting with "modal" hide their siblings while mounted; `scope=root` limits that to the probe root.
import * as React from "react"
import { createPortal } from "react-dom"
import { hideOthers } from "aria-hidden"
import { actionOf, items, isTemplate, templateName, only, type El } from "./_overlay"

const C = "shadcn---probe-hide-others"

function Hider({ child, parent }: { child: El; parent: () => HTMLElement }) {
  const ref = React.useRef<HTMLElement>(null)
  React.useEffect(() => hideOthers(ref.current!, parent()), [parent])
  return React.cloneElement(child, { ref })
}

function HideOthersProbe({ children, ...props }: Record<string, any>) {
  const rootRef = React.useRef<HTMLDivElement>(null)
  const list = items(children)
  const [open, setOpen] = React.useState<string[]>(() => list.filter((n) => isTemplate(n) && n.props["data-auto"] === "true").map((n) => templateName(n as El)))
  const scopeRoot = props[`data-${C}-scope-value`] === "root"
  const parent = React.useCallback(() => (scopeRoot ? rootRef.current! : document.body), [scopeRoot])

  const onClick = (e: React.MouseEvent) => {
    const action = actionOf(e.target, C)
    if (action?.method !== "toggle") return
    const name = action.params.name
    setOpen((names) => (names.includes(name) ? names.filter((n) => n !== name) : [...names, name]))
  }

  return (
    <div {...props} ref={rootRef} onClick={onClick}>
      {list.map((node) => {
        if (!isTemplate(node)) return node
        const name = templateName(node)
        if (!open.includes(name)) return null
        const content = only(node.props.children)
        const mounted = name.startsWith("modal") ? <Hider child={content} parent={parent} /> : content
        return node.props["data-into"] === "body" ? createPortal(mounted, document.body, String(node.key)) : <React.Fragment key={node.key}>{mounted}</React.Fragment>
      })}
    </div>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-hide-others", Component: HideOthersProbe }
