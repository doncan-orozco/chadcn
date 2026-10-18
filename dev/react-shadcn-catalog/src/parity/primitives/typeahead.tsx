// React twin of app/javascript/v2/primitives/typeahead.js: the typeahead built into the RAW Radix DropdownMenu (react-menu
// handleTypeaheadSearch), rendered open and inline over the tree's items. Item markers: role="menuitem" children of the node,
// `data-disabled` disables an item. `tabIndex` / `data-orientation` / `data-highlighted` / `aria-disabled` in the tree are the
// server-rendered values for Phlex (Radix owns them here), so they are stripped.
// The popper wrapper is made static so item boxes are comparable with the plain list on the Phlex side.
import * as React from "react"
import { DropdownMenu } from "radix-ui"

type AnyProps = Record<string, any>

function wrapItems(node: React.ReactNode): React.ReactNode {
  if (!React.isValidElement(node)) return node
  const props = node.props as AnyProps
  const kids = React.Children.map(props.children, wrapItems)
  if (props.role !== "menuitem") return React.cloneElement(node, undefined, kids)
  const { tabIndex: _t, "data-orientation": _o, "data-highlighted": _h, "aria-disabled": _a, "data-disabled": disabled, role: _r, children: _c, ...rest } = props
  return (
    <DropdownMenu.Item key={node.key} asChild disabled={disabled !== undefined} textValue={props["data-text-value"]}>
      {React.createElement(node.type, rest, kids)}
    </DropdownMenu.Item>
  )
}

function TypeaheadProbe({ children, ...props }: AnyProps) {
  const { tabIndex: _t, style: _s, "data-orientation": _o, "aria-orientation": _ao, role: _r, "data-state": _st, dir: _d, ...rest } = props
  return (
    <DropdownMenu.Root open modal={false}>
      <style>{"[data-radix-popper-content-wrapper]{position:static!important;transform:none!important;min-width:0!important}"}</style>
      <DropdownMenu.Trigger asChild><button hidden /></DropdownMenu.Trigger>
      <DropdownMenu.Content asChild loop>
        <div {...rest}>{React.Children.map(children, wrapItems)}</div>
      </DropdownMenu.Content>
    </DropdownMenu.Root>
  )
}

export const probe = { controller: "shadcn---probe-typeahead", Component: TypeaheadProbe }
