// Oracle for app/javascript/v2/primitives/hover_intent.js: RAW Radix Tooltip (Provider + skip delay) and HoverCard (open/close delays)
// over the scenario tree. Rendered by Harness.tsx for `_div[data-controller="chadcn---probe-hover-intent"]`; the Phlex side drives the
// same tree with dev/dummy/app/javascript/controllers/chadcn/_probe_hover_intent_controller.js.
//   data-parity-options: { kind: "tooltip"|"hover-card", side, sideOffset, delayDuration, skipDelayDuration, openDelay, closeDelay }
//   children: `[data-slot=trigger]` immediately followed by its `[data-slot=content]` (any other child is rendered untouched).
// Trigger/content data-state, ids and aria wiring are owned by Radix here and by the probe controller there, so the tree omits them.
import * as React from "react"
import { Tooltip, HoverCard } from "radix-ui"

type El = React.ReactElement<Record<string, unknown>>

function HoverIntentProbe({ children, ...props }: Record<string, unknown> & { children?: React.ReactNode }) {
  const { "data-parity-options": json, ...attrs } = props as Record<string, string>
  const o = JSON.parse(json ?? "{}")
  const kids = React.Children.toArray(children) as El[]
  const out: React.ReactNode[] = []
  for (let i = 0; i < kids.length; i++) {
    const kid = kids[i]
    if (kid.props["data-slot"] !== "trigger") {
      out.push(kid)
      continue
    }
    const content = kids[++i]
    const placement = { side: o.side, sideOffset: o.sideOffset, align: o.align }
    out.push(
      o.kind === "tooltip" ? (
        <Tooltip.Root key={kid.key}>
          <Tooltip.Trigger asChild>{kid}</Tooltip.Trigger>
          <Tooltip.Content asChild {...placement}>{content}</Tooltip.Content>
        </Tooltip.Root>
      ) : (
        <HoverCard.Root key={kid.key} openDelay={o.openDelay} closeDelay={o.closeDelay}>
          <HoverCard.Trigger asChild>{kid}</HoverCard.Trigger>
          <HoverCard.Content asChild {...placement}>{content}</HoverCard.Content>
        </HoverCard.Root>
      )
    )
  }
  const body = <div {...attrs}>{out}</div>
  return o.kind === "tooltip" ? (
    <Tooltip.Provider delayDuration={o.delayDuration} skipDelayDuration={o.skipDelayDuration} disableHoverableContent={!o.hoverable}>{body}</Tooltip.Provider>
  ) : (
    body
  )
}

export const probe = { controller: "chadcn---probe-hover-intent", Component: HoverIntentProbe }
