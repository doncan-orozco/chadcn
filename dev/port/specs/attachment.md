# Attachment (`Components::V2::Attachment`)

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/attachment.tsx` (style `new-york-v4`, source_sha `243feb168430d012`; byte-identical to upstream `apps/v4/registry/new-york-v4/ui/attachment.tsx` on 2026-10-09), manifest `gems/phlex-shadcn/dev/port/oracle/manifest/attachment.json`. Tier `static`: no Stimulus controller, no primitive. Exports `Attachment`, `AttachmentGroup`, `AttachmentMedia`, `AttachmentContent`, `AttachmentTitle`, `AttachmentDescription`, `AttachmentActions`, `AttachmentAction`, `AttachmentTrigger` (the cva tables `attachmentVariants` / `attachmentMediaVariants` are NOT exported, so no class method). Radix primitive used: `Slot` only (`AttachmentTrigger`: `const Comp = asChild ? Slot.Root : "button"`). Registry dependency: `button` (`AttachmentAction` renders `Button`).

## API

```ruby
Components::V2::Attachment.new(state: "done", size: "default", orientation: "horizontal", class: nil, **attrs) { ... }  # Attachment
Components::V2::Attachment::Group.new(class: nil, **attrs) { ... }                                                     # AttachmentGroup
Components::V2::Attachment::Media.new(variant: "icon", class: nil, **attrs) { ... }                                    # AttachmentMedia
Components::V2::Attachment::Content.new(class: nil, **attrs) { ... }                                                   # AttachmentContent
Components::V2::Attachment::Title.new(class: nil, **attrs) { ... }                                                     # AttachmentTitle
Components::V2::Attachment::Description.new(class: nil, **attrs) { ... }                                               # AttachmentDescription
Components::V2::Attachment::Actions.new(class: nil, **attrs) { ... }                                                   # AttachmentActions
Components::V2::Attachment::Action.new(variant: nil, size: "icon-xs", as_child: false, class: nil, **attrs) { ... }    # AttachmentAction
Components::V2::Attachment::Trigger.new(as_child: false, type: nil, class: nil, **attrs) { ... }                       # AttachmentTrigger
```

Name mapping (api-mapping.md, strip root prefix): `AttachmentGroup` -> `Attachment::Group`, `AttachmentMedia` -> `Attachment::Media`, `AttachmentContent` -> `Attachment::Content`, `AttachmentTitle` -> `Attachment::Title`, `AttachmentDescription` -> `Attachment::Description`, `AttachmentActions` -> `Attachment::Actions`, `AttachmentAction` -> `Attachment::Action`, `AttachmentTrigger` -> `Attachment::Trigger`; `Attachment` is the root class itself.

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `Attachment` | `state:` | `"done"` (`state = "done"`) | `idle`, `uploading`, `processing`, `error`, `done` (TS union; NOT a cva axis, it only feeds `data-state`) |
| `Attachment` | `size:` | `"default"` (`size = "default"`; cva has NO `defaultVariants`, the default comes from the destructuring) | `default`, `sm`, `xs` |
| `Attachment` | `orientation:` | `"horizontal"` (`orientation = "horizontal"`) | `horizontal`, `vertical` |
| `Attachment::Media` | `variant:` | `"icon"` (`variant = "icon"`; cva `defaultVariants.variant`) | `icon`, `image` |
| `Attachment::Action` | `variant:` | `nil` -> rendered as `"ghost"` (`variant={variant ?? "ghost"}`) | every `Components::V2::Button` variant |
| `Attachment::Action` | `size:` | `"icon-xs"` (`size = "icon-xs"`) | every `Components::V2::Button` size (`icon-sm` and `:icon_sm` both accepted, Button R4 rule) |
| `Attachment::Action` | `as_child:` | `false` (Button's `asChild`, passed through `...props`) | as `Components::V2::Button` |
| `Attachment::Trigger` | `as_child:` | `false` (`asChild = false`) | `false` \| tag symbol (`:a`) \| a V2 component instance |
| `Attachment::Trigger` | `type:` | `nil` -> `"button"` (`type={asChild ? undefined : (type ?? "button")}`) | any button type; ignored when `as_child` is set |
| all | `class:` | `nil` (`className`) | merged via `cn` after the base/variant classes |
| all | `**attrs` | `...props` (`React.ComponentProps<"div">` / `<"span">` / `<"button">` / `typeof Button`) | any HTML attribute: `id`, `role`, `title`, `tabindex`, `style`, `disabled`, `href` (as_child), `data: {}`, `aria: {}` / `"aria-*":` |

- Options accept strings and symbols (shadcn-port R4): `state: :error` == `"error"`, `size: :xs` == `"xs"`, `orientation: :vertical`, `variant: :image`. `nil` means the default. An option outside the TS union raises `ArgumentError` (consistent with the other V2 ports; cva would silently emit no variant classes).
- `Attachment::Action` is a thin wrapper: it renders `Components::V2::Button.new(variant: variant || "ghost", size: size, class: cn(class), "data-slot": "attachment-action", **attrs)`. Because React spreads `data-slot` into Button's `...props` (which Button spreads after its own `data-slot="button"`, button.tsx lines 54-58), the DOM carries `data-slot="attachment-action"`, `data-variant="ghost"` (or the given variant), `data-size="icon-xs"` (or the given size) and Button's full cva classes. A caller `"data-slot":` in `**attrs` wins over `"attachment-action"` (React: AttachmentAction's `{...props}` comes after its own `data-slot`; scenario `action__data-slot-override`). `as_child:` and `disabled:` behave exactly as in `gems/phlex-shadcn/dev/port/specs/button.md`; no `type` attribute is added (Button renders a bare `<button>` unless the caller passes `type`, scenario `action__variant-secondary__size-icon-sm` passes `type="button"` explicitly as the message example does).
- `Attachment::Trigger`: `type` is destructured, so it never reaches the element via `...props`. Without `as_child` the element gets `type="button"` unless the caller passes `type:` (scenario `trigger__type-submit`). With `as_child` the slot's `type` is `undefined`, so a caller `type:` is DROPPED and the child keeps whatever type it has itself (Radix `mergeProps`, `@radix-ui/react-slot/dist/index.mjs` lines 81-106: `{ ...slotProps, ...overrideProps }`; scenario `trigger__as-child-type-dropped`). Slot merge through `Components::V2::Base#render_as_child`: child props win (a child `data-slot` replaces `"attachment-trigger"`, scenario `trigger__as-child-child-data-slot-wins`), `class` is a PLAIN join slot-first-then-child with no tailwind_merge (the slot side is already `cn("absolute inset-0 z-10 outline-none", className)`; scenario `trigger__as-child-classname-join` keeps both `z-30` and the child's `z-0`), `style` slot-then-child, `data-action` child first then slot. Harness: `"asChild": true` with one `_a` / `_button` child.
- The Trigger renders no children of its own; a block is optional (React `children` via `...props`).
- Block = `children` for every part. Empty blocks render empty elements (`empty`, `content__empty`, `group__empty`).
- No `as:` kwarg on any part. Events: none dispatched (no `on*Change` in the source). `onClick` maps to `data: { action: ... }`. `ref`: no equivalent.

## Structure

Every part is one server-rendered element; nothing is set client-side, no ids, no `role`, no sr-only text, no icons owned by the component (manifest `icons: []`, `text_literals: []`).

```html
<div data-slot="attachment" data-state="{state}" data-size="{size}" data-orientation="{orientation}" class="{cn(attachmentVariants({size, orientation}), className)}">
  <div data-slot="attachment-media" data-variant="{variant}" class="{cn(attachmentMediaVariants({variant}), className)}"><svg .../> | <img/></div>
  <div data-slot="attachment-content" class="...">
    <span data-slot="attachment-title" class="...">name</span>
    <span data-slot="attachment-description" class="...">meta</span>
  </div>
  <div data-slot="attachment-actions" class="...">
    <button data-slot="attachment-action" data-variant="ghost" data-size="icon-xs" class="{buttonVariants}" aria-label="Remove">...</button>
  </div>
  <button data-slot="attachment-trigger" type="button" class="absolute inset-0 z-10 outline-none" aria-label="..."></button>
</div>
<div data-slot="attachment-group" class="...">...attachments...</div>
```

Attribute order per tsx part and override semantics (React spread last):
- `Attachment`: `data-slot="attachment"`, `data-state={state}`, `data-size={size}`, `data-orientation={orientation}`, `className`, `{...props}`. The three data attributes are always present (defaults render `data-state="done" data-size="default" data-orientation="horizontal"`). A caller `"data-state"` / `"data-orientation"` / `"data-slot"` in `**attrs` overrides them in the DOM because the spread comes last, and the `data-[state=...]` / `group-data-[...]/attachment:` styling then follows the DOM value while the cva classes still come from the kwargs (scenarios `api__data-state-attr-wins`, `api__data-orientation-attr-wins`, `api__data-slot-override`).
- `AttachmentMedia`: `data-slot="attachment-media"`, `data-variant={variant}`, `className`, `{...props}`.
- `AttachmentContent` / `AttachmentActions` / `AttachmentGroup`: `div`, `data-slot`, `className`, `{...props}`.
- `AttachmentTitle` / `AttachmentDescription`: `span` (block via class), `data-slot`, `className`, `{...props}`.
- `AttachmentAction`: Button element (see API).
- `AttachmentTrigger`: `button` (or the `as_child` element), `data-slot="attachment-trigger"`, `type`, `className`, `{...props}`.

DOM order is the caller's order; no part reorders or wraps children. The examples put `AttachmentTrigger` last as a direct child of `Attachment`; it covers the card (`absolute inset-0 z-10`) while `AttachmentActions` stays clickable above it (`relative z-20`).

Classes, verbatim from the tsx:

| part | tag | classes |
|---|---|---|
| `Attachment` (cva `attachmentVariants` base) | `div` | `group/attachment relative flex w-fit max-w-full min-w-0 shrink-0 flex-wrap rounded-xl border bg-card text-card-foreground transition-colors focus-within:ring-1 focus-within:ring-ring/50 has-[>a,>button]:hover:bg-muted/50 data-[state=error]:border-destructive/30 data-[state=idle]:border-dashed` |
| `AttachmentMedia` (cva `attachmentMediaVariants` base) | `div` | `relative flex aspect-square w-10 shrink-0 items-center justify-center overflow-hidden rounded-lg bg-muted text-foreground group-data-[orientation=vertical]/attachment:w-full group-data-[size=sm]/attachment:w-8 group-data-[size=xs]/attachment:w-7 group-data-[size=xs]/attachment:rounded-md group-data-[state=error]/attachment:bg-destructive/10 group-data-[state=error]/attachment:text-destructive group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6! [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 group-data-[orientation=vertical]/attachment:[&_svg:not([class*='size-'])]:size-6 group-data-[size=xs]/attachment:[&_svg:not([class*='size-'])]:size-3.5` |
| `AttachmentContent` | `div` | `max-w-full min-w-0 flex-1 leading-tight group-data-[orientation=vertical]/attachment:px-1` |
| `AttachmentTitle` | `span` | `block max-w-full min-w-0 truncate font-medium group-data-[state=processing]/attachment:shimmer group-data-[state=uploading]/attachment:shimmer` |
| `AttachmentDescription` | `span` | `cn("mt-0.5 block min-w-0 truncate text-xs text-muted-foreground group-data-[state=error]/attachment:text-destructive/80", "max-w-full", className)` (two literal arguments; output order keeps `max-w-full` last before the caller class) |
| `AttachmentActions` | `div` | `relative z-20 flex shrink-0 items-center group-data-[orientation=vertical]/attachment:absolute group-data-[orientation=vertical]/attachment:top-3 group-data-[orientation=vertical]/attachment:right-3 group-data-[orientation=vertical]/attachment:gap-1` |
| `AttachmentAction` | `button` | `Components::V2::Button.variants(variant: variant \|\| "ghost", size: "icon-xs")` + `cn(className)`; no own tokens |
| `AttachmentTrigger` | `button` (or child) | `absolute inset-0 z-10 outline-none` |
| `AttachmentGroup` | `div` | `flex min-w-0 scroll-fade-x snap-x snap-mandatory scroll-px-1 scrollbar-none gap-3 overflow-x-auto overscroll-x-contain py-1 *:data-[slot=attachment]:flex-none *:data-[slot=attachment]:snap-start` |

`attachmentVariants` (copied key for key; `compoundVariants`: none; `defaultVariants`: none, defaults come from `function Attachment` destructuring):
- `size.default`: `gap-2 text-sm has-data-[slot=attachment-content]:px-2.5 has-data-[slot=attachment-content]:py-2 has-data-[slot=attachment-media]:p-2`
- `size.sm`: `gap-2.5 text-xs has-data-[slot=attachment-content]:px-2 has-data-[slot=attachment-content]:py-1.5 has-data-[slot=attachment-media]:p-1.5`
- `size.xs`: `gap-1.5 rounded-lg text-xs has-data-[slot=attachment-content]:px-1.5 has-data-[slot=attachment-content]:py-1 has-data-[slot=attachment-media]:p-1`
- `orientation.horizontal`: `min-w-40 items-center`
- `orientation.vertical`: `w-24 flex-col has-data-[slot=attachment-content]:w-30`

`attachmentMediaVariants` (`compoundVariants`: none; `defaultVariants: { variant: "icon" }`):
- `variant.icon`: `` (empty string)
- `variant.image`: `opacity-60 group-data-[state=done]/attachment:opacity-100 group-data-[state=idle]/attachment:opacity-100 *:[img]:aspect-square *:[img]:w-full *:[img]:object-cover`

The manifest token list contains `icon`: it is a cva key picked up by the extractor, not a class; the port must not emit it.

Merge order per part: base, variant(s) (`size` then `orientation` for `Attachment`), caller `class`, all through `cn` (clsx + tailwind-merge). Conflicts resolved inside the cva output itself (React output, the port must match): `size: "xs"` drops the base `rounded-xl` (keeps `rounded-lg`); `orientation: "horizontal"` drops the base `min-w-0` (keeps `min-w-40`); `orientation: "vertical"` drops the base `w-fit` (keeps `w-24`) and keeps `min-w-0`. Caller-conflict cells pinned by scenarios: `class: "rounded-md"` drops `rounded-xl` (`api__classname-rounded`), xs + `"rounded-none"` drops `rounded-lg` (`api__classname-xs-rounded`), `"min-w-0"` drops `min-w-40` (`api__classname-min-w`), vertical + `"w-40"` drops `w-24` (`api__classname-vertical-width`), `"gap-4 text-base"` drops `gap-2 text-sm`, `"w-full"` drops `w-fit` (examples); Media `"rounded-full bg-primary text-primary-foreground"` drops `rounded-lg bg-muted text-foreground`; Content `"leading-normal flex-none"` drops `leading-tight flex-1`; Title `"font-semibold whitespace-normal"` drops `font-medium` and keeps `truncate` (tailwind-merge groups `truncate` under `text-overflow`, not `whitespace`, so both tokens stay; which `white-space` wins is decided by Tailwind's CSS order, identical on both sides); Description `"text-sm max-w-40 mt-0"` drops `text-xs max-w-full mt-0.5`; Actions `"gap-2 z-0"` drops `z-20`; Action `"rounded-full"` drops Button's `rounded-md`; Group `"gap-1 py-0"` drops `gap-3 py-1`.

Styling semantics the port must not alter (pure CSS, pinned by scenarios):
- `group/attachment` makes every descendant part react to the root's `data-state`, `data-size`, `data-orientation`: Media width (`w-10` / sm `w-8` / xs `w-7` / vertical `w-full`), Media radius xs `rounded-md`, icon size (`size-4`, xs `size-3.5`, vertical `size-6`), error colors on Media and Description, `shimmer` on Title for `uploading`/`processing`, image Media `opacity-60` except `done`/`idle`, Content `px-1` and Actions `absolute top-3 right-3 gap-1` when vertical.
- Root `has-data-[slot=attachment-content]:` / `has-data-[slot=attachment-media]:` padding: padding depends on which parts are present (`content-only`, `media-only__horizontal`, `orientation-vertical__media-only`, `orientation-vertical__content-only`).
- Root `has-[>a,>button]:hover:bg-muted/50`: hover background only when an `<a>` or `<button>` is a DIRECT child (the Trigger, or its `as_child` anchor); action buttons are inside `Attachment::Actions` and do not count (`hover__without-trigger`, `hover__nested-button-not-direct`, `trigger__hover`, `trigger__as-child-anchor`).
- Root `focus-within:ring-1 focus-within:ring-ring/50`: keyboard focus on the Trigger (which has `outline-none`) or on an Action rings the whole card (`trigger__focus-visible`, `action__focus-visible`).
- `data-[state=error]:border-destructive/30`, `data-[state=idle]:border-dashed` on the root.
- `group-data-[orientation=vertical]/attachment:*:data-[slot=spinner]:size-6!`: a direct child of Media with `data-slot="spinner"` (the registry `Spinner`) is forced to `size-6` in vertical orientation (`media__vertical-spinner-slot-child` vs `media__horizontal-spinner-slot-child`; these use a neutral `_span data-slot="spinner"` because `spinner` is not a registry dependency of attachment).
- Custom utilities: `shimmer` and `scroll-fade-x` are the shadcn `@utility` definitions in `app/assets/tailwind/vendor/shadcn-tailwind.css` (identical to the catalog's `gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/shadcn/dist/tailwind.css`, verified with `diff`). `scrollbar-none` is NOT defined by Tailwind v4 core nor by either stylesheet (only `no-scrollbar` exists), so it is a no-op on both sides; the port must still emit the token verbatim (G1) and must not define it.
- `dark:` tokens: none in attachment's own classes; dark mode changes only through the theme variables and Button's `dark:` tokens on `Attachment::Action`.
- No `aria-invalid:` or `disabled:` tokens of its own; `Attachment::Action` inherits Button's (`action__disabled`, `action__aria-invalid`).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::Attachment` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Attachment::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::Attachment::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `attachment.group` | `Attachment::Group` | `AttachmentGroup` |
| `attachment.media` | `Attachment::Media` | `AttachmentMedia` |
| `attachment.content` | `Attachment::Content` | `AttachmentContent` |
| `attachment.title` | `Attachment::Title` | `AttachmentTitle` |
| `attachment.description` | `Attachment::Description` | `AttachmentDescription` |
| `attachment.actions` | `Attachment::Actions` | `AttachmentActions` |
| `attachment.action` | `Attachment::Action` | `AttachmentAction` |
| `attachment.trigger` | `Attachment::Trigger` | `AttachmentTrigger` |

Names that shadow a Phlex HTML element inside `Attachment`'s OWN `view_template` (use `tag(:title)` there, never the bare method): `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Button` (`Attachment::Action`; spec `gems/phlex-shadcn/dev/port/specs/button.md`). Must be DONE before attachment is built.
- `Components::V2::Base` for `cn`, attribute merge and `render_as_child` (Slot, `Attachment::Trigger`).
- Scenarios use lucide icons through `<icon:...>`: `file-text`, `file-code`, `file-search`, `file-warning`, `clock`, `check`, `loader-circle`, `x`, `refresh-cw`, `copy`, `download`, `table`, `trash-2`.
- Registry examples: upstream `apps/v4/examples/radix/attachment-{demo,group,image,sizes,states,trigger}.tsx` and `message-attachment.tsx` (the `/r/styles/new-york-v4/attachment-demo.json` endpoint returns 404; examples import from `@/styles/radix-rhea/ui/attachment` and are rendered with the new-york-v4 oracle), each as `example__<slug>` plus a `__dark` twin. Scenario-level substitutions (identical on both harnesses, not component deviations):
  - Unsplash photo URLs -> inline `data:image/svg+xml` images (deterministic, no network in the parity run); `alt` texts kept.
  - `Spinner` (not a registry dependency of attachment, so the coverage check rejects its export) -> `<icon:loader-circle>`, as in the marker spec.
  - `attachment-trigger`: `Dialog`/`DialogTrigger asChild`/`DialogContent` dropped (not dependencies); the `AttachmentTrigger` with its `aria-label` stays, closed state. Full composition belongs to a cross-component scenario once `dialog` is DONE.
  - `message-attachment`: `Message`/`MessageContent`/`Bubble`/`BubbleContent` -> `_div` flex wrappers and `_p` text (not dependencies); the two attachments are unchanged.

## Deviations

None. No `deviations/attachment.json` is written.
