// Stub components that prove the harness before any real component uses it (see gems/phlex-shadcn/dev/port/scenarios/_harness.json).
// `_Probe` / `_ProbeGroup` / `_ProbeGroupItem` are the React twins of ShadcnParity::Probe / ProbeGroup / ProbeGroup::Item.
import * as React from "react"
import { Slot } from "radix-ui"
import { cn } from "@/lib/utils"

const VARIANTS: Record<string, string> = {
  default: "bg-primary text-primary-foreground",
  outline: "border bg-background text-foreground",
}

export function Probe({ variant = "default", asChild = false, className, ...props }: React.ComponentProps<"span"> & { variant?: string; asChild?: boolean }) {
  const Comp = asChild ? Slot.Root : "span"
  return (
    <Comp
      data-slot="probe"
      data-variant={variant}
      className={cn("inline-flex items-center gap-1 rounded-md px-2 py-1 text-sm font-medium [&_svg:not([class*='size-'])]:size-4", VARIANTS[variant], className)}
      {...props}
    />
  )
}

export function ProbeGroup({ className, ...props }: React.ComponentProps<"div">) {
  return <div data-slot="probe-group" className={cn("flex flex-col gap-2 rounded-lg border p-4", className)} {...props} />
}

export function ProbeGroupItem({ className, ...props }: React.ComponentProps<"div">) {
  return <div data-slot="probe-group-item" className={cn("text-sm text-muted-foreground", className)} {...props} />
}
