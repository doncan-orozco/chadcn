// React twin of app/javascript/v2/primitives/collection.js: the RAW @radix-ui/react-collection over the same markup.
// Tree contract (identical for the Phlex probe controller):
//   root            : _div[data-controller="chadcn---probe-collection"]
//   item            : any element with data-radix-collection-item (data-disabled = disabled item)
//   data-slot=list  : the container the buttons below add items to
//   buttons         : read (writes the ordered enabled items to out, all items to out-all), prepend / append (add an item
//                     to the list), toggle (flips data-disabled on [data-slot=item-b])
import * as React from "react"
import { createCollection } from "@radix-ui/react-collection"

type AnyProps = Record<string, any>
type ItemData = { disabled: boolean }

const [Collection, useCollection] = createCollection<HTMLElement, ItemData>("Probe")

const textOf = (el: HTMLElement) => (el.getAttribute("data-text-value") ?? el.textContent ?? "").trim()

function ProbeInner({ children, ...props }: AnyProps) {
  const getItems = useCollection(undefined)
  const [extras, setExtras] = React.useState({ front: 0, end: 0 })
  const [toggled, setToggled] = React.useState(false)
  const [out, setOut] = React.useState({ enabled: "", all: "" })

  const onClick = (slot: string) => {
    if (slot === "read") {
      const items = getItems()
      setOut({ enabled: items.filter((i) => !i.disabled).map((i) => textOf(i.ref.current!)).join(","), all: items.map((i) => textOf(i.ref.current!)).join(",") })
    }
    if (slot === "prepend") setExtras((e) => ({ ...e, front: e.front + 1 }))
    if (slot === "append") setExtras((e) => ({ ...e, end: e.end + 1 }))
    if (slot === "toggle") setToggled((t) => !t)
  }

  const extra = (kind: "front" | "end", n: number) => (
    <Collection.ItemSlot key={`${kind}-${n}`} scope={undefined} disabled={false}>
      <span data-slot={`item-${kind}-${n}`}>{`${kind === "front" ? "Front" : "End"} ${n}`}</span>
    </Collection.ItemSlot>
  )

  function walk(node: React.ReactNode): React.ReactNode {
    if (!React.isValidElement(node)) return node
    const p = node.props as AnyProps
    const slot = p["data-slot"] as string | undefined
    let kids = React.Children.map(p.children, walk)
    if (slot === "list") {
      kids = [
        ...Array.from({ length: extras.front }, (_, i) => extra("front", extras.front - i)),
        ...(kids ?? []),
        ...Array.from({ length: extras.end }, (_, i) => extra("end", i + 1)),
      ]
    }
    if (slot === "out") kids = [out.enabled]
    if (slot === "out-all") kids = [out.all]
    const { children: _c, "data-radix-collection-item": marker, ...rest } = p
    const extraProps: AnyProps = {}
    if (["read", "prepend", "append", "toggle"].includes(slot ?? "")) extraProps.onClick = () => onClick(slot!)
    if (marker === undefined) return React.cloneElement(node, extraProps, kids)
    const initiallyDisabled = p["data-disabled"] !== undefined
    const disabled = slot === "item-b" ? initiallyDisabled !== toggled : initiallyDisabled
    const { "data-disabled": _d, ...itemRest } = rest
    return (
      <Collection.ItemSlot key={node.key} scope={undefined} disabled={disabled}>
        {React.createElement(node.type, { ...itemRest, ...(disabled ? { "data-disabled": "" } : {}) }, kids)}
      </Collection.ItemSlot>
    )
  }

  const { children: _unused, ...rest } = props
  return (
    <Collection.Slot scope={undefined}>
      <div {...rest}>{React.Children.map(children, walk)}</div>
    </Collection.Slot>
  )
}

function CollectionProbe(props: AnyProps) {
  return (
    <Collection.Provider scope={undefined}>
      <ProbeInner {...props} />
    </Collection.Provider>
  )
}

export const probe = { controller: "chadcn---probe-collection", Component: CollectionProbe }
