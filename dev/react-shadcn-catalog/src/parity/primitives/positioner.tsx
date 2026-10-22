// Oracle for app/javascript/v2/primitives/positioner.js: the RAW @radix-ui/react-popper with the markup of the scenario tree.
// Tree contract (gems/chadcn/dev/port/scenarios/_primitives-positioner.json): a root `_div[data-controller="chadcn---probe-positioner"]` with
// `data-parity-options` (JSON: side sideOffset align alignOffset arrow arrowPadding avoidCollisions collisionPadding sticky hideWhenDetached)
// holding two children: the anchor, then the content. The probe controller on the Phlex side reads the same attributes.
import * as React from "react"
import * as Popper from "@radix-ui/react-popper"

type Options = Record<string, unknown> & { arrow?: boolean }

function PositionerProbe({ children, ...rest }: Record<string, unknown> & { children?: React.ReactNode }) {
  const { "data-parity-options": json, ...attrs } = rest as Record<string, string>
  const { arrow, boundary, ...options } = JSON.parse(json ?? "{}") as Options & { boundary?: string }
  const [collisionBoundary, setCollisionBoundary] = React.useState<Element | null>(null)
  React.useEffect(() => setCollisionBoundary(boundary ? document.querySelector(boundary) : null), [boundary])
  const [anchor, content] = React.Children.toArray(children) as React.ReactElement<{ children?: React.ReactNode }>[]
  const contentWithArrow = React.cloneElement(content, {}, content.props.children, arrow ? <Popper.Arrow key="arrow" data-slot="arrow" width={10} height={5} /> : null)
  return (
    <div {...attrs}>
      <Popper.Root>
        <Popper.Anchor asChild>{anchor}</Popper.Anchor>
        <Popper.Content asChild {...options} {...(collisionBoundary && { collisionBoundary })}>{contentWithArrow}</Popper.Content>
      </Popper.Root>
    </div>
  )
}

export const probe = { controller: "chadcn---probe-positioner", Component: PositionerProbe }
