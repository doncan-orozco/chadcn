// Oracle for app/javascript/v2/primitives/collapsible_content.js: the real @radix-ui/react-collapsible.
// Tree: root div > [trigger button, content div > <template>]. Radix generates the state attributes, so the ones the
// Phlex markup renders statically (data-state, aria-*, hidden, the SSR mount-prevention style) are dropped from the props handed to Radix.
import { Collapsible } from "radix-ui"
import { flag, items, isTemplate, type El } from "./_overlay"

const STATIC = ["style", "data-state", "aria-expanded", "aria-controls", "hidden", "id", "type"]
const strip = (props: Record<string, any>) => Object.fromEntries(Object.entries(props).filter(([k]) => !STATIC.includes(k)))

function CollapsibleContentProbe({ children, ...props }: Record<string, any>) {
  const [trigger, content] = items(children) as El[]
  const template = items(content.props.children).find(isTemplate) as El
  return (
    <Collapsible.Root {...strip(props)} defaultOpen={flag(props, "shadcn---probe-collapsible-content", "open")}>
      <Collapsible.Trigger {...strip(trigger.props)} />
      <Collapsible.Content {...strip(content.props)}>{template.props.children}</Collapsible.Content>
    </Collapsible.Root>
  )
}

// Harness.tsx renders the raw root whose data-controller is `controller` with this component.
export const probe = { controller: "shadcn---probe-collapsible-content", Component: CollapsibleContentProbe }
