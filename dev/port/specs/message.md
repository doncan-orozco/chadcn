# Message (`Components::V2::Message`)

Oracle: `dev/port/oracle/src/message.tsx` (style `new-york-v4`, source_sha `64e9ae0f9d1e268b`), manifest `dev/port/oracle/manifest/message.json`. Tier `static`: no Stimulus controller, no primitive, no Radix primitive (the tsx imports only `React` and `cn`; no `asChild`, no `Slot`). Exports `MessageGroup`, `Message`, `MessageAvatar`, `MessageContent`, `MessageFooter`, `MessageHeader`. No cva table, no `use client`.

## API

```ruby
Components::V2::Message::Group.new(class: nil, **attrs) { ... }                 # MessageGroup
Components::V2::Message.new(align: "start", class: nil, **attrs) { ... }        # Message
Components::V2::Message::Avatar.new(class: nil, **attrs) { ... }                # MessageAvatar
Components::V2::Message::Content.new(class: nil, **attrs) { ... }               # MessageContent
Components::V2::Message::Header.new(class: nil, **attrs) { ... }                # MessageHeader
Components::V2::Message::Footer.new(class: nil, **attrs) { ... }                # MessageFooter
```

Name mapping (api-mapping.md, strip the root prefix): `MessageGroup` -> `Message::Group`, `MessageAvatar` -> `Message::Avatar`, `MessageContent` -> `Message::Content`, `MessageHeader` -> `Message::Header`, `MessageFooter` -> `Message::Footer`; `Message` is the root class itself.

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `Message` | `align:` | `"start"` (`align = "start"` in `function Message`) | `start`, `end` (TS `align?: "start" \| "end"`); NOT a cva axis, it only feeds `data-align` |
| all | `class:` | `nil` (`className`) | merged via `cn` after the base classes |
| all | `**attrs` | `...props` (`React.ComponentProps<"div">`) | any HTML attribute: `id`, `role`, `title`, `dir`, `style`, `tabindex`, `data: {}`, `aria: {}` / `"aria-*":` |

- `align:` accepts strings and symbols (shadcn-port R4): `align: :end` == `"end"`; `nil` means the default `"start"`. A value outside the TS union raises `ArgumentError` (same policy as the other V2 ports).
- Block = `children`. Every part accepts text, raw elements, icons and other components (e.g. `Bubble`, `Avatar`, `Button`, `Attachment` from the registry examples); an empty block renders an empty `div` (`empty__all-parts`, `empty__message`, `avatar__empty`: the `message-group` example renders `<MessageAvatar />` with no children as a spacer).
- No `as:`, no `as_child:` (no `asChild` prop in the tsx), no `variant:`/`size:`, no class method (nothing like `messageVariants` is exported).
- Events: none dispatched (no `on*` props in the source). `ref`: no equivalent.

## Structure

Every part is one server-rendered `div`; nothing is set client-side, no ids generated, no `role`, no ARIA added, no sr-only text, no icons.

```html
<div data-slot="message-group" class="flex min-w-0 flex-col gap-2">
  <div data-slot="message" data-align="{align}" class="group/message relative flex w-full min-w-0 gap-2 text-sm data-[align=end]:flex-row-reverse">
    <div data-slot="message-avatar" class="flex w-fit min-w-8 shrink-0 items-center justify-center self-end overflow-hidden rounded-full bg-muted group-has-data-[slot=message-footer]/message:-translate-y-8">...</div>
    <div data-slot="message-content" class="flex w-full min-w-0 flex-col gap-2.5 wrap-break-word group-data-[align=end]/message:*:data-slot:self-end">
      <div data-slot="message-header" class="...">...</div>
      ...
      <div data-slot="message-footer" class="...">...</div>
    </div>
  </div>
</div>
```

Attribute order per tsx part and override semantics (React spreads `{...props}` last, so caller attributes win):
- `MessageGroup`: `data-slot="message-group"`, `className`, `{...props}`.
- `Message`: `data-slot="message"`, `data-align={align}`, `className`, `{...props}`. `align` is destructured, so the default always renders `data-align="start"`; a caller `"data-align"` in `**attrs` overrides the kwarg (`api__message-data-align-attr-wins`: no `align`, attr `data-align="end"` -> `flex-row-reverse` applies; `api__message-data-align-attr-over-prop`: `align: "end"` + attr `data-align="start"` -> the DOM shows `start`). A caller `data-slot` replaces `"message"` but the `group/message` class stays, so the children's `group-*/message` variants keep working (`api__message-data-slot-override`).
- `MessageAvatar`, `MessageContent`, `MessageHeader`, `MessageFooter`: `data-slot="message-{avatar,content,header,footer}"`, `className`, `{...props}`. A caller `data-slot` on `MessageFooter` replaces `"message-footer"`, which turns off the avatar's `has-data-[slot=message-footer]` translate (`api__footer-data-slot-override`).

DOM order is the caller's order; no part reorders, wraps or adds children. Visual order for `align="end"` comes from `data-[align=end]:flex-row-reverse` only (the avatar stays first in the DOM).

Classes, verbatim from the tsx (no cva; manifest `uses_cva: false` for every part):

| part | tag | data-slot | classes |
|---|---|---|---|
| `MessageGroup` | `div` | `message-group` | `flex min-w-0 flex-col gap-2` |
| `Message` | `div` | `message` (+ `data-align`) | `group/message relative flex w-full min-w-0 gap-2 text-sm data-[align=end]:flex-row-reverse` |
| `MessageAvatar` | `div` | `message-avatar` | `flex w-fit min-w-8 shrink-0 items-center justify-center self-end overflow-hidden rounded-full bg-muted group-has-data-[slot=message-footer]/message:-translate-y-8` |
| `MessageContent` | `div` | `message-content` | `flex w-full min-w-0 flex-col gap-2.5 wrap-break-word group-data-[align=end]/message:*:data-slot:self-end` |
| `MessageHeader` | `div` | `message-header` | `flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground group-has-data-[variant=ghost]/message:px-0` |
| `MessageFooter` | `div` | `message-footer` | `flex max-w-full min-w-0 items-center px-3 text-xs font-medium text-muted-foreground group-has-data-[variant=ghost]/message:px-0 group-data-[align=end]/message:justify-end` |

Merge order per part: base, then caller `class` through `cn` (clsx + tailwind-merge). Caller-conflict cells pinned by scenarios: `Message::Group class: "gap-4"` drops `gap-2` (`api__group-classname`); `Message class: "gap-4 text-base"` drops `gap-2` and `text-sm` (`api__message-classname`); `Message align: "end", class: "flex-row"` keeps both `flex-row` and `data-[align=end]:flex-row-reverse` (different modifier, no tailwind-merge conflict; `api__message-classname-flex-row__align-end`); `Message::Avatar class: "min-w-10 rounded-md bg-primary text-primary-foreground self-start"` drops `min-w-8`, `rounded-full`, `bg-muted`, `self-end` and keeps the `group-has-...:-translate-y-8` token (`api__avatar-classname`); `Message::Content class: "gap-4 w-auto"` drops `gap-2.5`, `w-full` (`api__content-classname`); `Message::Header class: "px-0 text-sm text-foreground"` drops `px-3`, `text-xs`, `text-muted-foreground`, keeps `group-has-data-[variant=ghost]/message:px-0` (`api__header-classname`); `Message::Footer class: "px-1 justify-start text-destructive"` drops `px-3` and `text-muted-foreground`, keeps `group-data-[align=end]/message:justify-end` (`api__footer-classname`). The registry `message-actions` example passes `MessageFooter className="gap-2"` (no conflict, appended).

Styling semantics the port must not alter (pure CSS, pinned by scenarios):
- `group/message` on `Message` is the anchor for every `group-*/message:` variant in the children (and for `Bubble`'s `group-data-[align=end]/message:self-end`, see `dev/port/specs/bubble.md`).
- `MessageContent`'s `group-data-[align=end]/message:*:data-slot:self-end` (Tailwind v4 `data-slot` bare variant = `&[data-slot]`, `*:` = direct children): in an end-aligned message only direct children that carry ANY `data-slot` attribute are pushed to the end; plain children without `data-slot` keep the stretch default (`content__data-slot-children__align-start` vs `__align-end`).
- `MessageAvatar`'s `group-has-data-[slot=message-footer]/message:-translate-y-8`: when the `Message` contains a `message-footer` anywhere among its descendants the avatar is lifted by `2rem` so it lines up with the last bubble instead of the footer (`avatar__without-footer`, `avatar__with-footer`, `avatar__with-footer__align-end`); outside a `Message` there is no `group/message` ancestor and nothing happens (`avatar__footer-outside-message`).
- `MessageHeader`/`MessageFooter` `group-has-data-[variant=ghost]/message:px-0`: any descendant of the `Message` with `data-variant="ghost"` (a ghost `Bubble`, or a ghost `Button` as in `message-actions`) removes their horizontal padding (`ghost-descendant__align-start`, `ghost-descendant__align-end`, `non-ghost-descendant` with `data-variant="outline"` keeps `px-3`, `example__message-actions`).
- `MessageFooter` `group-data-[align=end]/message:justify-end` right-aligns footer items in end messages (`footer__multiple-items__align-start` vs `__align-end`).
- `wrap-break-word` (`overflow-wrap: break-word`) plus `min-w-0` on content lets long unbroken words wrap (`content__long-text-wrap*`); header/footer `max-w-full min-w-0` constrain long labels (`header__long-text`).
- Layout uses physical flex direction only; `Message` does not read `dir`. Under `dir="rtl"` the flex main axis follows the writing direction, so `start`/`end` mirror (`rtl__align-start`, `rtl__align-end`).
- No `data-[state=*]`, `aria-invalid:`, `disabled:`, `hover:`, `focus-visible:`, `peer-*` or `dark:` tokens; dark mode changes only the theme tokens (`bg-muted`, `text-muted-foreground`), covered by the `__dark` twins.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Message` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Message::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Message::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `message.group` | `Message::Group` | `MessageGroup` |
| `message.avatar` | `Message::Avatar` | `MessageAvatar` |
| `message.content` | `Message::Content` | `MessageContent` |
| `message.footer` | `Message::Footer` | `MessageFooter` |
| `message.header` | `Message::Header` | `MessageHeader` |

Names that shadow a Phlex HTML element inside `Message`'s OWN `view_template` (use `tag(:footer)` there, never the bare method): `footer`, `header`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- None rendered by the component (`registry_dependencies: []`, no lucide import). Needs `Components::V2::Base` for `cn` and attribute merge only.
- Scenarios use lucide icons via `<icon:...>` (`bot`, `copy`, `thumbs-up`, `thumbs-down`, `refresh-ccw`, `image`, `file-text`, `download`) in raw-element stand-ins only.
- Example substitutions (scenario-level only, identical on both harnesses, not component deviations). Upstream examples are `apps/v4/examples/radix/message-{actions,attachment,avatar,demo,group,header-footer,markdown}.tsx` (the `/r/styles/new-york-v4/message-*.json` endpoints return 404; the `message-scroller-*` examples belong to the separate `message-scroller` component). They compose `Bubble`, `Avatar`, `Button`, `Attachment` and `Marker`, none of which is a registry dependency of `message`, so the coverage check rejects their exports. Each such part is replaced by a raw `_div`/`_span`/`_button` that carries exactly the `data-*` attributes the real part emits by default (`data-slot`, plus `data-variant`/`data-align` for `Bubble`, `data-variant`/`data-size` for `Button`, `data-state`/`data-size`/`data-orientation` for `Attachment`, `data-variant` for `AttachmentMedia`, `data-size` for `Avatar`; values from the dependency tsx defaults), because these are the attributes `Message`'s selectors read (`*:data-slot`, `has-data-[slot=message-footer]`, `has-data-[variant=ghost]`). Their classes are omitted. Further changes: `AvatarImage` (`/avatars/*.png`, not shipped) dropped, fallback text kept; the unsplash `<img>` in `message-attachment` replaced by `<icon:image>` (no network in the harness); the `Marker` "is typing..." row of `message-demo` dropped; the docs-site `Markdown` in `message-markdown` replaced by `_p`/`_ol`/`_li`/`_strong`/`_code` with the same text. Full compositions become cross-component scenarios once `bubble`, `avatar`, `button`, `attachment` and `marker` are DONE.

## Deviations

None. No `deviations/message.json` is written.
