// React twin of app/javascript/v2/primitives/form_bubble_input.js: the RAW Radix Checkbox / Switch / RadioGroup / Select whose
// internal BubbleInput the port reproduces. Rendered by Harness.tsx for `data-controller="chadcn---probe-form-bubble-input"`; the Phlex side
// renders the markup from the scenario tree and the Stimulus probe (_probe_form_bubble_input_controller.js) adds the bubble input.
//   root props : data-slot="form" renders a <form>, anything else a <div> (the no-form case);
//                data-probe-kind checkbox|switch|radio|select, -name, -value, -checked (true|indeterminate), -required, -disabled,
//                -options (JSON [{value,label}]), -selected (initial radio / select value). The tree children are the Phlex markup only.
// A `log` output mirrors what the form observes natively: events that reach it and the FormData it would submit.
import * as React from "react"
import { Checkbox, RadioGroup, Select, Switch } from "radix-ui"

type AnyProps = Record<string, any>

const CONTROL = "inline-flex size-5 items-center justify-center rounded border border-input text-xs data-[state=checked]:bg-primary data-[state=checked]:text-primary-foreground data-[state=indeterminate]:bg-primary"

function FormBubbleInputProbe({ children: _children, ...rest }: AnyProps) {
  const kind = rest["data-probe-kind"] as "checkbox" | "switch" | "radio" | "select"
  const name = rest["data-probe-name"] ?? "field"
  const value = rest["data-probe-value"] ?? "on"
  const checkedProp = rest["data-probe-checked"] as string | undefined
  const defaultChecked = checkedProp === "true"
  const required = rest["data-probe-required"] === "true"
  const disabled = rest["data-probe-disabled"] === "true"
  const options: { value: string; label: string }[] = JSON.parse(rest["data-probe-options"] ?? "[]")
  const defaultValue = rest["data-probe-selected"] ?? ""
  const noForm = rest["data-slot"] !== "form"
  const formRef = React.useRef<HTMLFormElement>(null)
  const [log, setLog] = React.useState("")
  const [selectValue, setSelectValue] = React.useState(defaultValue)
  const [controlledChecked, setControlledChecked] = React.useState<boolean | "indeterminate">(checkedProp === "indeterminate" ? "indeterminate" : false)

  const rootRef = React.useRef<HTMLDivElement>(null)

  React.useEffect(() => {
    const host = (formRef.current ?? rootRef.current)!
    const counts = { click: 0, change: 0 }
    const bubble = () => host.querySelector<HTMLInputElement | HTMLSelectElement>("[aria-hidden=true]")
    const render = () => {
      const el = bubble()
      const data = formRef.current ? [...new FormData(formRef.current).entries()].map(([k, v]) => `${k}=${v}`).join("&") : ""
      setLog(`click=${counts.click} change=${counts.change} input=${el ? (el instanceof HTMLSelectElement ? el.value : (el as HTMLInputElement).checked) : "none"} data=${data}`)
    }
    const onClick = (e: Event) => { if ((e.target as HTMLElement).getAttribute("aria-hidden") === "true") counts.click++; render() }
    const onChange = () => { counts.change++; render() }
    host.addEventListener("click", onClick)
    host.addEventListener("change", onChange)
    // Radix settles the bubble input after the control registers itself; look once everything is in place.
    const timer = setTimeout(() => { host.querySelectorAll("[aria-hidden=true]").forEach((el) => el.setAttribute("data-slot", "bubble")); render() }, 50)
    return () => { clearTimeout(timer); host.removeEventListener("click", onClick); host.removeEventListener("change", onChange) }
  }, [])

  const control = () => {
    if (kind === "checkbox") {
      return (
        <Checkbox.Root data-slot="control" className={CONTROL} name={name} value={value} required={required} disabled={disabled} {...(checkedProp === "indeterminate" ? { checked: controlledChecked, onCheckedChange: setControlledChecked } : { defaultChecked })}>
          <Checkbox.Indicator>x</Checkbox.Indicator>
        </Checkbox.Root>
      )
    }
    if (kind === "switch") {
      return (
        <Switch.Root data-slot="control" className="inline-flex h-5 w-9 items-center rounded-full border border-input data-[state=checked]:bg-primary" name={name} value={value} required={required} disabled={disabled} defaultChecked={defaultChecked}>
          <Switch.Thumb className="block size-4 rounded-full bg-foreground" />
        </Switch.Root>
      )
    }
    if (kind === "radio") {
      return (
        <RadioGroup.Root name={name} required={required} disabled={disabled} defaultValue={defaultValue} className="flex gap-2">
          {options.map((o) => (
            <RadioGroup.Item key={o.value} value={o.value} data-slot="control" className={CONTROL}>
              <RadioGroup.Indicator>o</RadioGroup.Indicator>
            </RadioGroup.Item>
          ))}
        </RadioGroup.Root>
      )
    }
    return (
      <>
        <Select.Root name={name} required={required} disabled={disabled} value={selectValue} onValueChange={setSelectValue}>
          <Select.Trigger className="inline-flex items-center gap-2 rounded border border-input px-2 py-1 text-sm">
            <Select.Value placeholder="Pick" />
          </Select.Trigger>
          <Select.Portal>
            <Select.Content>
              <Select.Viewport>
                {options.map((o) => (
                  <Select.Item key={o.value} value={o.value}>
                    <Select.ItemText>{o.label}</Select.ItemText>
                  </Select.Item>
                ))}
              </Select.Viewport>
            </Select.Content>
          </Select.Portal>
        </Select.Root>
        {options.slice(1, 2).map((o) => (
          <button key={o.value} type="button" data-slot="set" className="rounded border px-2 py-1 text-sm" onClick={() => setSelectValue(o.value)}>
            set {o.value}
          </button>
        ))}
      </>
    )
  }

  const body = (
    <div ref={rootRef} className="flex items-center gap-3">
      {control()}
      <output data-slot="log" className="text-xs">{log}</output>
    </div>
  )
  return noForm ? <div {...rest}>{body}</div> : (
    <form ref={formRef} {...rest} onSubmit={(e) => e.preventDefault()}>
      {body}
    </form>
  )
}

export const probe = { controller: "chadcn---probe-form-bubble-input", Component: FormBubbleInputProbe }
