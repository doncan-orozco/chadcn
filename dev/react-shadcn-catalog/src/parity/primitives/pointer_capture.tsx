// React twin of app/javascript/v2/primitives/pointer_capture.js: the RAW Radix Slider (its SliderImpl owns the
// setPointerCapture / hasPointerCapture / releasePointerCapture handlers). Rendered by Harness.tsx for
// `data-controller="shadcn---probe-pointer-capture"`; the Phlex side renders the markup of the scenario tree and the Stimulus probe
// (_probe_pointer_capture_controller.js) drives the primitive. Config: data-probe-value / -min / -max / -step on the root;
// the tree children are the Phlex markup only.
// The readout shows what the drag produced: value, commits and how many pointermoves happened with the capture held.
import * as React from "react"
import { Slider } from "radix-ui"

type AnyProps = Record<string, any>

function PointerCaptureProbe({ children: _children, ...rest }: AnyProps) {
  const defaultValue = Number(rest["data-probe-value"] ?? 25)
  const min = Number(rest["data-probe-min"] ?? 0)
  const max = Number(rest["data-probe-max"] ?? 100)
  const step = Number(rest["data-probe-step"] ?? 1)
  const [value, setValue] = React.useState(defaultValue)
  const [commits, setCommits] = React.useState(0)
  const [moves, setMoves] = React.useState({ total: 0, captured: 0 })

  return (
    <div {...rest}>
      <Slider.Root
        data-probe="root"
        className="relative flex h-5 w-full touch-none items-center select-none"
        defaultValue={[defaultValue]}
        min={min}
        max={max}
        step={step}
        onValueChange={([v]) => setValue(v)}
        onValueCommit={() => setCommits((n) => n + 1)}
        onPointerMove={(e) => setMoves((m) => ({ total: m.total + 1, captured: m.captured + ((e.target as Element).hasPointerCapture(e.pointerId) ? 1 : 0) }))}
      >
        <Slider.Track className="relative h-1.5 w-full grow rounded-full bg-muted">
          <Slider.Range className="absolute h-full rounded-full bg-primary" />
        </Slider.Track>
        <Slider.Thumb aria-label="Value" className="block size-4 rounded-full border border-primary bg-background" />
      </Slider.Root>
      <output data-slot="readout" className="text-xs">{`value=${value} commits=${commits} moves=${moves.total} captured=${moves.captured}`}</output>
      <div data-slot="outside" data-probe="outside" className="h-16 w-full rounded border" />
    </div>
  )
}

export const probe = { controller: "shadcn---probe-pointer-capture", Component: PointerCaptureProbe }