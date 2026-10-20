// Oracle side of the parity contract (.ai/skills/shadcn-port/references/parity-gates.md, "Harness contract").
// Route: /#/parity/<component>/<scenarioId>. Renders the scenario `tree` with the real catalog components, no chrome.
// Tree rules (identical in ShadcnParity::TreeRenderer):
//   - c = "_a" / "_div" ... (underscore + lowercase): raw HTML element, props become attributes
//   - c = "_Probe" ... (underscore + capital): harness stub component from ./probes
//   - children strings are text; a string starting with "<icon:name>" renders that lucide icon (rest of the string is text)
//   - a child `{ "c": "_Each", "children": [template...] }` turns the parent's children into a render function (Base UI lists,
//     groups and multiple-value chips): the template is rendered once per element of the argument (Array) or once with it;
//     "$item" / "$item.<path>" in a string prop or text child are replaced by that element (not inside a nested `_Each`)
//   - a string prop value "$ref:<css selector>" becomes a lazy ref ({ current: document.querySelector(selector) }); the Phlex
//     side passes the selector string
import * as React from "react"
import * as Lucide from "lucide-react"
import * as probes from "./probes"

// Parity only: SidebarMenuSkeleton draws its width from Math.random() (floor(r * 40) + 50 percent). Pin r = 0.5 (70 percent)
// so it matches the Phlex parity controller, which pins the same width.
Math.random = () => 0.5

const modules = import.meta.glob("../components/ui/*.tsx", { eager: true }) as Record<string, Record<string, unknown>>
const registry: Record<string, React.ElementType> = {}
for (const mod of Object.values(modules)) {
  for (const [name, value] of Object.entries(mod)) if (/^[A-Z]/.test(name) && value) registry[name] = value as React.ElementType
}

// Raw-element probes for the shared primitives (./primitives/*.tsx): a raw `_` node whose `data-controller` equals a module's
// `probe.controller` is rendered by that module's React twin (raw Radix) instead of a bare element, so the SAME tree drives
// the Stimulus probe controller on the Phlex side.
const primitiveModules = import.meta.glob("./primitives/*.tsx", { eager: true }) as Record<string, { probe?: { controller: string; Component: React.ElementType } }>
const primitiveProbes: Record<string, React.ElementType> = {}
for (const mod of Object.values(primitiveModules)) if (mod.probe) primitiveProbes[mod.probe.controller] = mod.probe.Component

const scenarioFiles = import.meta.glob("@scenarios/*.json")

type Node = { c: string; props?: Record<string, unknown>; children?: Array<Node | string> }
type Scenario = { id: string; tree: Node }

const FONT_URL = "https://fonts.googleapis.com/css2?family=Fraunces:wght@400;600;700&family=Manrope:wght@400;500;600;700&display=swap"

const FONT_STACK = 'ui-sans-serif, system-ui, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"'

class ParityError extends Error {}

const pascal = (s: string) => s.split("-").map((p) => p.charAt(0).toUpperCase() + p.slice(1)).join("")

function icon(name: string, key?: React.Key) {
  const Icon = (Lucide as unknown as Record<string, React.ElementType>)[`${pascal(name)}Icon`] ?? (Lucide as unknown as Record<string, React.ElementType>)[pascal(name)]
  if (!Icon) throw new ParityError(`unknown icon ${name}`)
  return <Icon key={key} />
}

function renderChild(child: Node | string, key: number): React.ReactNode {
  if (typeof child !== "string") return renderNode(child, key)
  const m = child.match(/^<icon:([\w-]+)>/)
  if (!m) return child
  const rest = child.slice(m[0].length)
  return (
    <React.Fragment key={key}>
      {icon(m[1])}
      {rest}
    </React.Fragment>
  )
}

const isEach = (child: Node | string): child is Node => typeof child !== "string" && child.c === "_Each"

// "$item" / "$item.a.b" -> the element (or its property). Does not descend into the children of a nested `_Each`.
function substitute(value: unknown, item: unknown): unknown {
  if (typeof value === "string") {
    if (value === "$item") return item
    if (value.startsWith("$item.")) return value.slice(6).split(".").reduce<unknown>((acc, part) => (acc as Record<string, unknown> | undefined)?.[part], item)
    return value
  }
  if (Array.isArray(value)) return value.map((v) => substitute(v, item))
  if (value && typeof value === "object") {
    const node = value as Node
    if (typeof node.c === "string") {
      return { ...node, props: substitute(node.props ?? {}, item), children: isEach(node) ? node.children : (node.children ?? []).map((c) => substitute(c, item)) }
    }
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, substitute(v, item)]))
  }
  return value
}

function expandEach(each: Node, arg: unknown, key: number): React.ReactNode {
  const elements = Array.isArray(arg) ? arg : [arg]
  return elements.map((element, index) => (
    <React.Fragment key={`${key}-${index}-${JSON.stringify(element)}`}>
      {(each.children ?? []).map((template, i) => renderChild(substitute(template, element) as Node | string, i))}
    </React.Fragment>
  ))
}

const lazyRef = (selector: string) => ({ get current() { return document.querySelector(selector) } })

function refProps(props: Record<string, unknown>) {
  return Object.fromEntries(Object.entries(props).map(([k, v]) => [k, typeof v === "string" && v.startsWith("$ref:") ? lazyRef(v.slice(5)) : v]))
}

function renderNode(node: Node, key?: number): React.ReactNode {
  const props = { ...refProps(node.props ?? {}), key }
  const each = (node.children ?? []).find(isEach)
  if (each) {
    const render = (arg: unknown) => (node.children ?? []).map((child, i) => (child === each ? expandEach(each, arg, i) : renderChild(child, i)))
    const component = registry[node.c]
    if (!component) throw new ParityError(`unknown component ${node.c}`)
    return React.createElement(component, props, render)
  }
  const kids = (node.children ?? []).map(renderChild)
  const children = kids.length ? kids : undefined
  if (/^_[a-z]/.test(node.c)) {
    const Probe = primitiveProbes[String(props["data-controller" as keyof typeof props] ?? "")]
    return Probe ? React.createElement(Probe, props, children) : React.createElement(node.c.slice(1), props, children)
  }
  const component = node.c.startsWith("_") ? (probes as Record<string, React.ElementType>)[node.c.slice(1)] : registry[node.c]
  if (!component) throw new ParityError(`unknown component ${node.c}`)
  // A lone child stays a single element: Radix Slot (asChild) rejects an array.
  return React.createElement(component, props, kids.length === 1 ? kids[0] : children)
}

function parseHash() {
  const m = window.location.hash.match(/^#\/parity\/([^/]+)\/([^/?]+)/)
  return m ? { component: decodeURIComponent(m[1]), scenario: decodeURIComponent(m[2]) } : null
}

export default function Harness() {
  const [state, setState] = React.useState<{ node?: React.ReactNode; error?: string }>({})

  React.useEffect(() => {
    document.documentElement.style.fontSize = "16px"
    document.body.className = "bg-background text-foreground"
    // Same font files as the host stylesheet (app/assets/tailwind/application.css).
    const font = document.createElement("link")
    font.rel = "stylesheet"
    font.href = FONT_URL
    document.head.appendChild(font)
    // The catalog's Tailwind release ships another default font stack than the host's compiler; pin one stack on both sides
    // (ShadcnParity::Page sets the same value) so font drift never masquerades as a component diff.
    const stack = document.createElement("style")
    stack.textContent = `:root{--font-sans:${FONT_STACK}}`
    document.head.appendChild(stack)
    const route = parseHash()
    if (!route) return setState({ error: "bad parity route" })
    const key = Object.keys(scenarioFiles).find((k) => k.endsWith(`/${route.component}.json`))
    if (!key) return setState({ error: `no scenarios for ${route.component}` })
    scenarioFiles[key]()
      .then((mod) => {
        const file = ((mod as { default?: unknown }).default ?? mod) as { scenarios: Scenario[] }
        const scenario = file.scenarios.find((s) => s.id === route.scenario)
        if (!scenario) throw new ParityError(`unknown scenario ${route.scenario}`)
        setState({ node: renderNode(scenario.tree) })
      })
      .catch((e: Error) => setState({ error: e.message }))
  }, [])

  if (state.error) return <div data-parity-error="">{state.error}</div>
  return <div className="p-8">{state.node}</div>
}
