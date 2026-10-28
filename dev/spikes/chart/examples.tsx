// Spike examples rendered by oracle_ssr.mjs: the two shadcn chart blocks (stacked bar, monotone line) with the shadcn chart wrapper.
// Data are fixed (no randomness) so the committed oracle HTML is reproducible.
import * as React from "react"
import { createRoot } from "react-dom/client"
import { flushSync } from "react-dom"
import { Bar, BarChart, CartesianGrid, Line, LineChart, XAxis, YAxis } from "recharts"
import {
  ChartContainer, ChartLegend, ChartLegendContent, ChartTooltip, ChartTooltipContent, type ChartConfig,
} from "../../react-shadcn-catalog/src/components/ui/chart"

export const barData = [
  { month: "January", desktop: 186, mobile: 80 },
  { month: "February", desktop: 305, mobile: 200 },
  { month: "March", desktop: 237, mobile: 120 },
  { month: "April", desktop: 73, mobile: 190 },
  { month: "May", desktop: 209, mobile: 130 },
  { month: "June", desktop: 214, mobile: 140 },
]

export const lineData = [
  { month: "January", desktop: 186 },
  { month: "February", desktop: 305 },
  { month: "March", desktop: 237 },
  { month: "April", desktop: 73 },
  { month: "May", desktop: 209 },
  { month: "June", desktop: 214 },
]

const barConfig = {
  desktop: { label: "Desktop", color: "var(--chart-1)" },
  mobile: { label: "Mobile", color: "var(--chart-2)" },
} satisfies ChartConfig

const lineConfig = { desktop: { label: "Desktop", color: "var(--chart-1)" } } satisfies ChartConfig

export const bar = () => (
    <ChartContainer id="spike-bar" config={barConfig}>
      <BarChart accessibilityLayer data={barData}>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="month" tickLine={false} tickMargin={10} axisLine={false} tickFormatter={(value) => String(value).slice(0, 3)} />
        <ChartTooltip defaultIndex={1} content={<ChartTooltipContent hideLabel />} />
        <ChartLegend content={<ChartLegendContent />} />
        <Bar dataKey="desktop" stackId="a" fill="var(--color-desktop)" radius={[0, 0, 4, 4]} isAnimationActive={false} />
        <Bar dataKey="mobile" stackId="a" fill="var(--color-mobile)" radius={[4, 4, 0, 0]} isAnimationActive={false} />
      </BarChart>
    </ChartContainer>
)

export const line = () => (
    <ChartContainer id="spike-line" config={lineConfig}>
      <LineChart accessibilityLayer data={lineData} margin={{ left: 12, right: 12 }}>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="month" tickLine={false} axisLine={false} tickMargin={8} tickFormatter={(value) => String(value).slice(0, 3)} />
        <YAxis tickLine={false} axisLine={false} tickMargin={8} />
        <ChartTooltip cursor={false} content={<ChartTooltipContent hideLabel />} />
        <Line dataKey="desktop" type="monotone" stroke="var(--color-desktop)" strokeWidth={2} dot={true} isAnimationActive={false} />
      </LineChart>
    </ChartContainer>
)

// Client render into `host`, committed synchronously; effects are flushed by the caller waiting for frames.
export function mount(name: "bar" | "line", host: HTMLElement) {
  const root = createRoot(host)
  flushSync(() => root.render(name === "bar" ? bar() : line()))
  return root
}
