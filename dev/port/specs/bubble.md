# Bubble (`Components::V2::Bubble`)

Oracle: `gems/chadcn/dev/port/oracle/src/bubble.tsx` (style `new-york-v4`, source_sha `df1e461e33e835b7`; byte-identical to upstream `apps/v4/registry/new-york-v4/ui/bubble.tsx` on 2026-10-09), manifest `gems/chadcn/dev/port/oracle/manifest/bubble.json`. Tier `static`: no Stimulus controller, no primitive. Exports `BubbleGroup`, `Bubble`, `BubbleContent`, `BubbleReactions` (the two cva tables `bubbleVariants` / `bubbleReactionsVariants` are NOT exported). Radix primitive used: `Slot` only (`BubbleContent`: `const Comp = asChild ? Slot.Root : "div"`).

## API

```ruby
Components::V2::Bubble::Group.new(class: nil, **attrs) { ... }                                   # BubbleGroup
Components::V2::Bubble.new(variant: "default", align: "start", class: nil, **attrs) { ... }      # Bubble
Components::V2::Bubble::Content.new(as_child: false, class: nil, **attrs) { ... }                # BubbleContent
Components::V2::Bubble::Reactions.new(side: "bottom", align: "end", class: nil, **attrs) { ... } # BubbleReactions
```

Name mapping (api-mapping.md, strip root prefix): `BubbleGroup` -> `Bubble::Group`, `BubbleContent` -> `Bubble::Content`, `BubbleReactions` -> `Bubble::Reactions`; `Bubble` is the root class itself.

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `Bubble::Group` | `class:` | `nil` (`className`) | merged via `cn` after the base |
| `Bubble` | `variant:` | `"default"` (`variant = "default"` in `function Bubble`; cva `defaultVariants.variant`) | `default`, `secondary`, `muted`, `tinted`, `outline`, `ghost`, `destructive` |
| `Bubble` | `align:` | `"start"` (`align = "start"`) | `start`, `end` (TS `align?: "start" \| "end"`; NOT a cva axis, it only feeds `data-align`) |
| `Bubble::Content` | `as_child:` | `false` (`asChild = false`) | `false` \| tag symbol (`:button`, `:a`) \| a V2 component instance |
| `Bubble::Reactions` | `side:` | `"bottom"` (`side = "bottom"`; cva `defaultVariants.side`) | `top`, `bottom` |
| `Bubble::Reactions` | `align:` | `"end"` (`align = "end"`; cva `defaultVariants.align`) | `start`, `end` |
| all | `**attrs` | `...props` (`React.ComponentProps<"div">`) | any HTML attribute: `id`, `role`, `title`, `tabindex`, `style`, `data: {}`, `aria: {}` / `"aria-*":` |

- Options accept strings and symbols (shadcn-port R4): `variant: :tinted` == `"tinted"`, `side: :top` == `"top"`. `nil` means the default. An option outside the TS union raises `ArgumentError` (consistent with the other V2 ports; cva would silently emit no variant classes).
- Note the two different `align` defaults: `Bubble` defaults to `"start"`, `Bubble::Reactions` defaults to `"end"` (tsx lines `align = "start"` and `align = "end"`).
- No `size:` axis, no `as:`, no class method (cva tables are module-private in the tsx, so no `Bubble.variants`).
- Block = `children`. `Bubble::Content` accepts text, raw elements, icons, other components; empty renders an empty `div`.
- `as_child:` on `Bubble::Content` only (the other parts have no `asChild`). Radix `Slot.Root` merge via `Components::V2::Base#render_as_child` (`@radix-ui/react-slot` `mergeProps`): child props win (a child `data-slot` replaces `"bubble-content"`, which also detaches the parent `Bubble`'s `*:data-[slot=bubble-content]:` styling, scenario `api__content-as-child-child-data-slot-wins`), `class` is a PLAIN join slot-first-then-child with no tailwind_merge (`api__content-as-child-anchor-classname`, `api__content-as-child-child-classname-conflict`: both `rounded-xl` and the child's `rounded-none`, both `px-3` and `px-6` stay in the DOM), `style` slot-then-child, `data-action` child first then slot. Harness: `"asChild": true` with one `_button` / `_a` child.
- `as_child` matters for styling: every hover token is `[&>[data-slot=bubble-content]:is(button,a):hover]:` on `Bubble`, and every focus token is `[button,a]:` on `Bubble::Content` (Tailwind v4 arbitrary variant without `&` = `&:is(button,a)`), so only a content element that IS a `<button>`/`<a>` gets hover/focus/transition/text-left styling.
- Events: none dispatched (no `on*` props in the source). `ref`: no equivalent.

## Structure

Every part is one server-rendered element; nothing is set client-side, no ids, no ARIA added, no `role`, no sr-only text, no icons.

```html
<div data-slot="bubble-group" class="flex min-w-0 flex-col gap-2">
  <div data-slot="bubble" data-variant="{variant}" data-align="{align}" class="{cn(bubbleVariants({variant}), className)}">
    <div data-slot="bubble-content" class="w-fit max-w-full ... [button,a]:focus-visible:ring-ring/50">...</div>
    <div data-slot="bubble-reactions" data-align="{align}" data-side="{side}" class="{cn(bubbleReactionsVariants({side, align}), className)}">...</div>
  </div>
</div>
```

Attribute order per tsx part and override semantics (React spread last):
- `BubbleGroup`: `data-slot="bubble-group"`, `className`, `{...props}`.
- `Bubble`: `data-slot="bubble"`, `data-variant={variant}`, `data-align={align}`, `className`, `{...props}`. `variant`/`align` are destructured, so the kwargs always produce the data attributes (defaults render `data-variant="default" data-align="start"`), but a caller `"data-align"` / `"data-variant"` / `"data-slot"` in `**attrs` overrides them because the spread comes last (scenario `api__bubble-data-align-attr-wins`: `align` defaults to `start`, attr `data-align="end"` wins in the DOM and triggers `data-[align=end]:self-end`).
- `BubbleContent`: `data-slot="bubble-content"`, `className`, `{...props}` (caller `data-slot` wins, `api__content-data-slot-override`).
- `BubbleReactions`: `data-slot="bubble-reactions"`, `data-align={align}`, `data-side={side}`, `className`, `{...props}`. Note the attribute order is `data-align` before `data-side`.

DOM order is the caller's order; no part reorders or wraps children. `Bubble::Reactions` is placed by `absolute` against the `relative` `Bubble`; its DOM position inside `Bubble` does not matter visually.

Classes, verbatim from the tsx:

| part | tag | classes |
|---|---|---|
| `BubbleGroup` | `div` | `flex min-w-0 flex-col gap-2` |
| `Bubble` (cva `bubbleVariants` base) | `div` | `group/bubble relative flex w-fit max-w-[80%] min-w-0 flex-col gap-1 group-data-[align=end]/message:self-end data-[align=end]:self-end data-[variant=ghost]:max-w-full` |
| `BubbleContent` | `div` (or the `as_child` element) | `w-fit max-w-full min-w-0 overflow-hidden rounded-xl border border-transparent px-3 py-2 text-sm leading-relaxed wrap-break-word group-data-[align=end]/bubble:self-end [button]:text-left [button,a]:transition-colors [button,a]:outline-none [button,a]:focus-visible:border-ring [button,a]:focus-visible:ring-3 [button,a]:focus-visible:ring-ring/50` |
| `BubbleReactions` (cva `bubbleReactionsVariants` base) | `div` | `absolute z-10 flex w-fit shrink-0 items-center justify-center gap-1 rounded-full bg-muted px-1.5 py-0.5 text-sm ring-3 ring-card has-[button]:p-0` |

`bubbleVariants.variant` (copied key for key; `compoundVariants`: none; `defaultVariants: { variant: "default" }`):
- `default`: `*:data-[slot=bubble-content]:bg-primary *:data-[slot=bubble-content]:text-primary-foreground [&>[data-slot=bubble-content]:is(button,a):hover]:bg-primary/80`
- `secondary`: `*:data-[slot=bubble-content]:bg-secondary *:data-[slot=bubble-content]:text-secondary-foreground [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--secondary),var(--foreground)_5%)]`
- `muted`: `*:data-[slot=bubble-content]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[color-mix(in_oklch,var(--muted),var(--foreground)_5%)]`
- `tinted`: `*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.93_calc(c*0.4)_h)] *:data-[slot=bubble-content]:text-foreground dark:*:data-[slot=bubble-content]:bg-[oklch(from_var(--primary)_0.3_calc(c*0.4)_h)] [&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.88_calc(c*0.5)_h)] dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-[oklch(from_var(--primary)_0.35_calc(c*0.5)_h)]`
- `outline`: `*:data-[slot=bubble-content]:border-border *:data-[slot=bubble-content]:bg-background [&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-input/30`
- `ghost`: `border-none *:data-[slot=bubble-content]:rounded-none *:data-[slot=bubble-content]:bg-transparent *:data-[slot=bubble-content]:p-0 [&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted [&>[data-slot=bubble-content]:is(button,a):hover]:text-foreground dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-muted/50`
- `destructive`: `*:data-[slot=bubble-content]:bg-destructive/10 *:data-[slot=bubble-content]:text-destructive dark:*:data-[slot=bubble-content]:bg-destructive/20 [&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/20 dark:[&>[data-slot=bubble-content]:is(button,a):hover]:bg-destructive/30`

`bubbleReactionsVariants` (`compoundVariants`: none; `defaultVariants: { side: "bottom", align: "end" }`):
- `side.top`: `top-0 -translate-y-3/4`; `side.bottom`: `bottom-0 translate-y-3/4`
- `align.start`: `left-3`; `align.end`: `right-3`

The manifest token list contains `default`, `bottom`, `end`: these are cva keys picked up by the extractor, not classes; the port must not emit them.

Merge order per part: base, variant(s), caller `class`, through `cn` (clsx + tailwind-merge). Caller-conflict cells pinned by scenarios: `Bubble class: "max-w-full"` drops `max-w-[80%]` but keeps `data-[variant=ghost]:max-w-full`; `class: "gap-3"` drops `gap-1`; `Content class: "rounded-none"` drops `rounded-xl`; `"px-4 py-1"` drops `px-3 py-2`; `Reactions class: "p-0"` drops `px-1.5 py-0.5` (keeps `has-[button]:p-0`), `"ring-0"` drops `ring-3` and keeps `ring-card`, `"top-2 translate-y-0"` drops `top-0` and `-translate-y-3/4`; `Group class: "gap-4"` drops `gap-2`.

Merge-library note (scenario `api__content-classname-wrap`): the catalog's `cn` uses tailwind-merge 2.6.1, which has no overflow-wrap group (no `break-word` in `node_modules/tailwind-merge/dist/bundle-mjs.mjs`), so React keeps BOTH `wrap-break-word` and a caller `wrap-anywhere`. The Ruby `tailwind_merge` 1.5.0 config defines `"wrap" => [{ "wrap" => ["break-word", "anywhere", "normal"] }]` (`lib/tailwind_merge/config.rb:1073`) and would drop `wrap-break-word`. Parity requires the React DOM; this is a shared `cn` configuration matter (`Components::Base`, owned by the infra wave), not a bubble deviation. The scenario stays.

Styling semantics the port must not alter (pure CSS, pinned by scenarios):
- `Bubble` colors its content through `*:data-[slot=bubble-content]:` = direct children with that data-slot only. A `Bubble::Content` nested deeper, or one whose `data-slot` was overridden, is not colored.
- Alignment: `data-[align=end]:self-end` (needs a flex parent, e.g. `Bubble::Group` or the example wrapper; `context__no-flex-parent` shows it has no effect otherwise), `group-data-[align=end]/message:self-end` (an ancestor `group/message` with `data-align="end"`, used by the registry `message` component; `context__message-group-align-*`), and content `group-data-[align=end]/bubble:self-end` (each content right-aligns inside an end bubble; `content__multiple-contents__align-end`).
- `ghost`: `data-[variant=ghost]:max-w-full` lifts the 80% cap; content loses padding/radius/background.
- `tinted` uses CSS relative color syntax `oklch(from var(--primary) ...)` and `secondary`/`muted` hovers use `color-mix(in oklch, ...)`; both are theme-neutral (only `--primary`, `--secondary`, `--muted`, `--foreground`).
- Reactions: `ring-3 ring-card` draws a card-colored halo; `has-[button]:p-0` removes padding when a button is inside.
- No `data-[state=*]`, `aria-invalid:`, `disabled:` or `peer-*` tokens. `dark:` tokens only in `tinted`, `outline`, `ghost`, `destructive`.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Bubble` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Bubble::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Bubble::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `bubble.group` | `Bubble::Group` | `BubbleGroup` |
| `bubble.content` | `Bubble::Content` | `BubbleContent` |
| `bubble.reactions` | `Bubble::Reactions` | `BubbleReactions` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- None rendered by the component (`registry_dependencies: []`, no lucide import).
- Needs `Components::V2::Base` for `cn`, attribute merge and `render_as_child` (Slot).
- Scenarios use lucide icons via `<icon:...>` (`check`, `chevron-down`, `info`).
- Example substitutions (scenario-level only, identical on both harnesses, not component deviations). Upstream examples are `apps/v4/examples/radix/bubble-{alignment,collapsible,demo,group-demo,link-button,markdown,popover,reactions,tooltip,variants}.tsx` (the `/r/styles/new-york-v4/bubble-*.json` endpoints return 404; examples import from `@/styles/radix-rhea/ui/bubble`, rendered here with the new-york-v4 oracle). Bubble has no registry dependency on `Button`, `Tooltip`, `Popover` or `Collapsible`, so the coverage check rejects their exports:
  - `bubble-popover`, `bubble-reactions`, `bubble-tooltip`: `Button` (and the `PopoverTrigger`/`TooltipTrigger` wrapping it) -> `_button` with the example's `aria-label`/`className`; popover/tooltip content omitted (closed state). `bubble-collapsible`: `Collapsible` -> `_div`, `CollapsibleTrigger asChild > Button` -> `_button` with the example's className and `<icon:chevron-down>`, rendered closed (`text.slice(0, 180) + "..."`, label "Show more").
  - `bubble-markdown`, `bubble-variants`: the docs-site `Markdown` component -> plain `_p` / `_strong` / `_code` elements carrying the same text.
  - `bubble-link-button`, `bubble-reactions`: `onClick` toast handlers (sonner) dropped.
  - Full compositions belong to cross-component scenarios once `button`, `tooltip`, `popover`, `collapsible` are DONE.

## Deviations

None. No `deviations/bubble.json` is written.
