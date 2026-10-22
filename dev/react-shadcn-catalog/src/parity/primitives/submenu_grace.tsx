// Oracle for app/javascript/v2/primitives/submenu_grace.js: the RAW Radix DropdownMenu (react-menu pointer-grace area, pointer
// direction, sub open delay) over the scenario tree. Rendered by Harness.tsx for `_div[data-controller="shadcn---probe-submenu-grace"]`;
// the Phlex side drives the same tree with gems/chadcn/dev/dummy/app/javascript/controllers/shadcn/_probe_submenu_grace_controller.js.
// Tree contract (data-slot decides the part, anything else is rendered untouched):
//   root > trigger (anchor button) , menu > [ item* , sub-trigger , sub-content > item* , item* ]
// Roving tabindex, data-highlighted, data-state, aria-* and role are owned by Radix here and by the probe controller there.
import * as React from "react"
import { DropdownMenu } from "radix-ui"

type El = React.ReactElement<Record<string, any>>

function rebuild(node: El, children: React.ReactNode): El {
  return React.cloneElement(node, undefined, children)
}

function wrapChildren(children: React.ReactNode): React.ReactNode[] {
  const kids = React.Children.toArray(children) as El[]
  const out: React.ReactNode[] = []
  for (let i = 0; i < kids.length; i++) {
    const kid = kids[i]
    const slot = kid.props?.["data-slot"]
    if (slot === "sub-trigger") {
      const subContent = kids[++i]
      out.push(
        <DropdownMenu.Sub key={kid.key}>
          <DropdownMenu.SubTrigger asChild>{kid}</DropdownMenu.SubTrigger>
          <DropdownMenu.SubContent asChild>{rebuild(subContent, wrapChildren(subContent.props.children))}</DropdownMenu.SubContent>
        </DropdownMenu.Sub>
      )
    } else if (slot === "item") {
      out.push(<DropdownMenu.Item key={kid.key} asChild>{kid}</DropdownMenu.Item>)
    } else {
      out.push(kid)
    }
  }
  return out
}

function SubmenuGraceProbe({ children, ...props }: Record<string, any>) {
  const { "data-parity-options": json, ...attrs } = props
  const o = JSON.parse(json ?? "{}")
  const kids = React.Children.toArray(children) as El[]
  return (
    <div {...attrs}>
      <DropdownMenu.Root open modal={false}>
        {kids.map((kid) =>
          kid.props["data-slot"] === "trigger" ? (
            <DropdownMenu.Trigger key={kid.key} asChild>{kid}</DropdownMenu.Trigger>
          ) : kid.props["data-slot"] === "menu" ? (
            <DropdownMenu.Content key={kid.key} asChild side={o.side} align={o.align} sideOffset={o.sideOffset}>
              {rebuild(kid, wrapChildren(kid.props.children))}
            </DropdownMenu.Content>
          ) : (
            kid
          )
        )}
      </DropdownMenu.Root>
    </div>
  )
}

export const probe = { controller: "shadcn---probe-submenu-grace", Component: SubmenuGraceProbe }
