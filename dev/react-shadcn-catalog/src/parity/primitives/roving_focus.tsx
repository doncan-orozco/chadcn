// React twin of app/javascript/v2/primitives/roving_focus.js: the RAW @radix-ui/react-roving-focus group over the same markup.
// Rendered by Harness.tsx for `_div[data-controller="shadcn---probe-roving-focus"]`; the Phlex side wires the Stimulus probe
// (gems/chadcn/dev/dummy/app/javascript/controllers/shadcn/_probe_roving_focus_controller.js) to the identical tree.
//   group props : data-roving-loop="true", data-roving-dir="rtl|ltr", data-orientation (server value; Radix recomputes it)
//   item marker : data-roving-item (item), data-disabled (focusable=false), data-active (Radix `active`)
// `tabIndex` / `data-orientation` / `style` in the tree are the SERVER-rendered values for Phlex; Radix owns them here, so they are stripped.
import * as React from "react"
import * as RovingFocusGroup from "@radix-ui/react-roving-focus"

type AnyProps = Record<string, any>

function wrapItems(node: React.ReactNode): React.ReactNode {
  if (!React.isValidElement(node)) return node
  const props = node.props as AnyProps
  const kids = React.Children.map(props.children, wrapItems)
  if (props["data-roving-item"] === undefined) return React.cloneElement(node, undefined, kids)
  const { tabIndex: _tabIndex, "data-orientation": _orientation, children: _children, ...rest } = props
  return (
    <RovingFocusGroup.Item key={node.key} asChild tabStopId={props.id} focusable={props["data-disabled"] === undefined} active={props["data-active"] !== undefined}>
      {React.createElement(node.type, rest, kids)}
    </RovingFocusGroup.Item>
  )
}

function RovingFocusProbe({ children, ...props }: AnyProps) {
  const { tabIndex: _tabIndex, style: _style, "data-orientation": orientation, ...rest } = props
  return (
    <RovingFocusGroup.Root asChild orientation={orientation} loop={props["data-roving-loop"] === "true"} dir={props["data-roving-dir"]} defaultCurrentTabStopId={props["data-roving-current"]}>
      <div {...rest}>{React.Children.map(children, wrapItems)}</div>
    </RovingFocusGroup.Root>
  )
}

export const probe = { controller: "shadcn---probe-roving-focus", Component: RovingFocusProbe }
