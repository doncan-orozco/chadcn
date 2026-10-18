// React twin of app/javascript/v2/primitives/direction.js: the RAW @radix-ui/react-direction (Provider + useDirection).
// Tree contract: _div[data-controller="shadcn---probe-direction"] with
//   data-provider-dir : value of the enclosing DirectionProvider (absent = no provider); on the Phlex side the server writes
//                       the same value to the consumer's own `dir` attribute, which is what direction.js reads
//   data-local-dir    : the consumer's own `dir` prop (absent = none)
// Both sides write the result to `data-resolved`.
import * as React from "react"
import { Direction } from "radix-ui"

type AnyProps = Record<string, any>

function Consumer({ children, ...props }: AnyProps) {
  const resolved = Direction.useDirection(props["data-local-dir"] || undefined)
  return <div {...props} data-resolved={resolved}>{children}</div>
}

function DirectionProbe(props: AnyProps) {
  const provider = props["data-provider-dir"]
  const consumer = <Consumer {...props} />
  return provider === undefined ? consumer : <Direction.DirectionProvider dir={provider || undefined}>{consumer}</Direction.DirectionProvider>
}

export const probe = { controller: "shadcn---probe-direction", Component: DirectionProbe }
