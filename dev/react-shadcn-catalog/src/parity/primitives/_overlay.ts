// Shared helpers of the overlay-family primitive probes (this directory's *.tsx files, default-exported by name; see
// gems/phlex-shadcn/dev/port/scenarios/_primitives-*.json). A probe scenario is a RAW element tree whose root carries
// `data-probe="<name>"`; the Harness renders that root with the matching component instead of a plain element.
// The Phlex side renders the very same tree and wires it with a Stimulus probe controller (`shadcn---probe-<name>`),
// so the markup lives once, in the scenario. `<template>` children are the conditional (mounted-on-demand) content.
import * as React from "react"

export type El = React.ReactElement<Record<string, any>>

export const isTemplate = (node: React.ReactNode): node is El => React.isValidElement(node) && node.type === "template"

/** Root children in order, with `<template>` elements flagged (their children are what React mounts conditionally). */
export function items(children: React.ReactNode): React.ReactNode[] {
  return React.Children.toArray(children)
}

export const templateName = (template: El): string => template.props["data-name"] ?? "default"

/** `data-action="click->shadcn---probe-x#method"` of the closest actionable ancestor, with its `*-param` attributes. */
export function actionOf(target: EventTarget | null, controller: string): { method: string; params: Record<string, string>; element: Element } | null {
  const element = (target as Element | null)?.closest?.("[data-action]")
  if (!element) return null
  const match = element.getAttribute("data-action")!.match(new RegExp(`->${controller}#(\\w+)`))
  if (!match) return null
  const params: Record<string, string> = {}
  const prefix = `data-${controller}-`
  for (const attr of Array.from(element.attributes)) {
    if (attr.name.startsWith(prefix) && attr.name.endsWith("-param")) params[attr.name.slice(prefix.length, -"-param".length)] = attr.value
  }
  return { method: match[1], params, element }
}

export const flag = (props: Record<string, any>, controller: string, name: string): boolean => props[`data-${controller}-${name}-value`] === "true"

/** The single element inside a `<template>` (the harness hands children over as an array). */
export const only = (children: React.ReactNode): El => React.Children.toArray(children)[0] as El
