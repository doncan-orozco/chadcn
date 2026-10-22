# Avatar

Oracle: `dev/port/oracle/src/avatar.tsx` (manifest `source_sha` 0c5c48b8a1dff4fd, tier `radix_stateful`), wrapping `AvatarPrimitive.Root` / `Image` / `Fallback` from `radix-ui` -> `@radix-ui/react-avatar` 1.2.7 (`dev/react-shadcn-catalog/node_modules/@radix-ui/react-avatar/dist/index.mjs`, cited below as `avatar.mjs:<line>`). `AvatarBadge`, `AvatarGroup`, `AvatarGroupCount` are plain elements (no Radix). Registry examples: only `avatar-demo` (`https://ui.shadcn.com/r/styles/new-york-v4/avatar-demo.json`); `empty-avatar*` and `item-avatar` belong to other components.

## API

Six exports, six Ruby classes (name rule: strip the `Avatar` prefix).

```ruby
Components::V2::Avatar.new(size: "default", as_child: false, class: nil, **attrs) { ... }
Components::V2::Avatar::Image.new(src: nil, referrer_policy: nil, cross_origin: nil, as_child: false, class: nil, **attrs)
Components::V2::Avatar::Fallback.new(delay_ms: nil, as_child: false, class: nil, **attrs) { ... }
Components::V2::Avatar::Badge.new(class: nil, **attrs) { ... }
Components::V2::Avatar::Group.new(class: nil, **attrs) { ... }
Components::V2::Avatar::GroupCount.new(class: nil, **attrs) { ... }
```

| Part | kwarg | Default (source) | Options / notes |
|---|---|---|---|
| `Avatar` | `size:` | `"default"` (avatar.tsx `size = "default"`) | `"default"`, `"sm"`, `"lg"` (TS type `"default" \| "sm" \| "lg"`); strings and symbols (shadcn-port R4); `nil` = default; unknown option raises `ArgumentError` (forbidden by the TS type). Rendered as `data-size`. No cva table: sizing is `data-[size=...]` on the Root and `group-data-[size=...]/avatar` on children. |
| `Avatar` | `as_child:` | `false` | Radix `Primitive.span` supports `asChild` (Slot). `false` \| tag symbol (`as_child: :a`) \| V2 component instance, via `Components::V2::Base#render_as_child` (Radix `mergeProps`; see api-mapping.md). The resulting element is the controller host. |
| `Avatar::Image` | `src:` | `nil` | Image URL. `nil`/`""` -> status `error` immediately (avatar.mjs:95-97 `if (!src)`), so the image never mounts. |
| `Avatar::Image` | `referrer_policy:` | `nil` | React `referrerPolicy`. Applied to the preloader (avatar.mjs:107-109) AND rendered on the mounted `<img>` as `referrerpolicy` (it stays in `imageProps`, avatar.mjs:50,70). |
| `Avatar::Image` | `cross_origin:` | `nil` | React `crossOrigin`. Preloader `crossOrigin = crossOrigin ?? null` (avatar.mjs:110) and rendered on the `<img>` as `crossorigin`. |
| `Avatar::Image` | `as_child:` | `false` | Radix `Primitive.img` supports Slot. Same semantics as above. |
| `Avatar::Fallback` | `delay_ms:` | `nil` | React `delayMs` (passed through shadcn's `...props` to the primitive, avatar.mjs:76). `nil` -> renderable immediately (avatar.mjs:78 `useState(delayMs === void 0)`); an Integer -> renderable only after `delay_ms` milliseconds (avatar.mjs:79-84). |
| `Avatar::Fallback` | `as_child:` | `false` | Radix `Primitive.span` supports Slot. |
| `Badge`, `Group`, `GroupCount` | (none) | | Plain `span` / `div` / `div` in shadcn (`React.ComponentProps<"span">`/`<"div">`); no `as_child`, no other kwargs. |

- Every part: `class:` merged last through `cn` (tailwind_merge), caller wins; `**attrs` (`id`, `alt`, `title`, `aria: {}`, `data: {}`, `"aria-label":`, `role`...) pass through and deep-merge (shadcn-port R6). `alt:` on `Avatar::Image` is a plain attr.
- `Avatar`: avatar.tsx renders `data-slot="avatar" data-size={size}` BEFORE `{...props}`, so a caller `data: { size: }` / `data: { slot: }` in `**attrs` overrides them (React spread semantics). `class` is not overridable that way (destructured into `cn`).
- Events: `chadcn--avatar:loading-status-change`, `detail: { status }` with `status` in `"idle" | "loading" | "loaded" | "error"` (Radix `onLoadingStatusChange`, avatar.mjs:50,59-69, a prop of `AvatarImage`). Dispatched from the Avatar Root element (the controller host; the `<img>` is not in the DOM until loaded), bubbles, not cancelable (Radix's callback is not preventable). Fired only when the status differs from the previous one, the previous one starting at the context value of the first render, `"idle"` (avatar.mjs:62-68).
- `ref` has no equivalent.

## Structure

React output (`Primitive.span`/`Primitive.img`, avatar.mjs:42,70,85):

```html
<span data-slot="avatar" data-size="default" class="<Avatar classes>">
  <img data-slot="avatar-image" class="aspect-square size-full" src="..." alt="...">   <!-- only while status == loaded -->
  <span data-slot="avatar-fallback" class="<Fallback classes>">CN</span>              <!-- only while status != loaded and the delay elapsed -->
  <span data-slot="avatar-badge" class="<Badge classes>"></span>                        <!-- caller-placed, optional -->
</span>
```

Order is the caller's JSX order; Image and Fallback mount/unmount in place (React re-inserts at the JSX position).

Part `Avatar` (Root, `data-slot="avatar"`):
- tag `span` (avatar.mjs:42 `Primitive.span`; the caller's tag with `as_child`), `data-slot="avatar"`, `data-size="default|sm|lg"` (always present), no role, no aria, no `data-state` (Radix Avatar sets none).
- Classes verbatim: `group/avatar relative flex size-8 shrink-0 overflow-hidden rounded-full select-none data-[size=lg]:size-10 data-[size=sm]:size-6`, then `class:`.

Part `Avatar::Image` (`data-slot="avatar-image"`):
- tag `img`, attributes: `data-slot="avatar-image"`, `class`, caller attrs (`alt`, ...), `referrerpolicy`/`crossorigin` when given, `src` (avatar.mjs:70 `{...imageProps, src}`). Mounted ONLY when the loading status is `loaded`; otherwise no element at all (avatar.mjs:70 returns `null`).
- Classes verbatim: `aspect-square size-full`, then `class:`.

Part `Avatar::Fallback` (`data-slot="avatar-fallback"`):
- tag `span`, `data-slot="avatar-fallback"`, `class`, caller attrs, children. Mounted iff `canRender && status !== "loaded"` (avatar.mjs:85): without `delay_ms` it is present from the first paint (SSR and no-JS render it); with `delay_ms` it is absent until the timer fires.
- Classes verbatim: `flex size-full items-center justify-center rounded-full bg-muted text-sm text-muted-foreground group-data-[size=sm]/avatar:text-xs`, then `class:`.

Part `Avatar::Badge` (`data-slot="avatar-badge"`):
- tag `span`, `data-slot="avatar-badge"`, children (typically a lucide icon), always rendered by the server, no JS.
- Classes verbatim (avatar.tsx joins five strings through `cn`; same token set): `absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-full bg-primary text-primary-foreground ring-2 ring-background select-none group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2 group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2`, then `class:`.

Part `Avatar::Group` (`data-slot="avatar-group"`):
- tag `div`, `data-slot="avatar-group"`, static.
- Classes verbatim: `group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background`, then `class:`.

Part `Avatar::GroupCount` (`data-slot="avatar-group-count"`):
- tag `div`, `data-slot="avatar-group-count"`, static, children (text like `+3` or an icon).
- Classes verbatim: `relative flex size-8 shrink-0 items-center justify-center rounded-full bg-muted text-sm text-muted-foreground ring-2 ring-background group-has-data-[size=lg]/avatar-group:size-10 group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 group-has-data-[size=sm]/avatar-group:[&>svg]:size-3`, then `class:`.

Server vs Stimulus (controller `chadcn--avatar`, host = the Avatar Root element):
- The server renders Root, Badge, Group, GroupCount exactly as above, and a Fallback WITHOUT `delay_ms` as a live element (identical to React SSR, works without JS).
- `Avatar::Image` is server-rendered as the complete `<img data-slot="avatar-image" ...>` inside an inert `<template data-chadcn--avatar-target="image">` at its position. A Fallback WITH `delay_ms` is rendered the same way inside `<template data-chadcn--avatar-target="fallback" data-chadcn--avatar-delay-ms-value="...">` (or an equivalent value carrier on the template). Template contents are not part of the document, so the snapshot (and the a11y tree) equals React's "not mounted"; the template node itself is declared in Deviations.
- To unmount a live Fallback when the image loads, the controller swaps it for a `<template data-chadcn--avatar-target="fallback">` holding it (so it can be restored); to mount, it swaps a template for its content in place. DOM order is therefore always the caller's order.
- No ids are generated; no aria is set by the component.

## Behavior

Composes no shared primitive: the planned set (`.ai/skills/radix-stimulus/references/primitives.md`) has no image-loading module, and in Radix this logic is private to `react-avatar` (avatar.mjs:88-124, no other package uses it), so it lives in the `chadcn--avatar` controller. (radix-stimulus "Media/layout" lists an `image-loading-status` helper; if the orchestrator adds it as a primitive, the controller uses it instead.) No focus, keyboard, pointer, dismissal, scroll lock, Presence or positioning: Radix Avatar has none (avatar.mjs contains no event handlers besides image `load`/`error`).

States (Radix `ImageLoadingStatus`, avatar.mjs:15-20): `idle` -> `loading` -> `loaded` | `error`. One status per Root (context, avatar.mjs:30-32), shared by Image and Fallback.

Transitions (useImageLoadingStatus, avatar.mjs:88-120, run in a layout effect on Image mount and whenever `src`, `crossOrigin`, `referrerPolicy` change):
1. No `src` (nil/empty): status := `error` (avatar.mjs:95-97). Image stays unmounted, Fallback (if renderable) stays.
2. Otherwise create a detached `new window.Image()`, attach `load` and `error` listeners, set `referrerPolicy` if given, `crossOrigin = cross_origin ?? null`, then `src` (avatar.mjs:99-111), and immediately set status := `getImageLoadingStatus(image)` (avatar.mjs:112): `complete ? (naturalWidth > 0 ? "loaded" : "error") : "loading"` (avatar.mjs:122-124). Cached images can therefore go straight to `loaded` in the same frame.
3. `load` event: status := `getImageLoadingStatus(image)` (so a decoded image with `naturalWidth == 0` is `error`); `error` event: status := `error` (avatar.mjs:100-104).
4. Cleanup (Image disconnect / src change): remove both listeners, status := `idle` (avatar.mjs:113-117). Port: the image target's disconnect (and the controller's `disconnect()`) does the same and restores the server DOM (Image back into its template, Fallback mounted) so a Turbo cache snapshot or morph never keeps a stale `loaded` state; `connect()` is idempotent.

Rendering rules:
- Image is in the DOM iff status == `loaded` (avatar.mjs:70). On `loaded` the controller replaces the image template with its `<img>` (cloned, same attributes, `src` set) and unmounts the Fallback.
- Fallback is in the DOM iff its delay elapsed AND status != `loaded` (avatar.mjs:85). Without an Image part the status stays `idle`, so the Fallback always shows.
- `delay_ms`: a `window.setTimeout(delay_ms)` started on connect sets `canRender`; cleared on disconnect (avatar.mjs:79-84). Timer is per Fallback, independent of the image status. If the image loads before the delay, the Fallback never appears.
- `loading-status-change` is dispatched after each status change that differs from the previous value (avatar.mjs:62-68); typical sequences: `loading` -> `loaded`, `loading` -> `error`, or `error` alone (no src).
- Radix's development-only multiple-Image warning (avatar.mjs:126-153) has no port equivalent (console only, not part of the DOM).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Avatar` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Avatar::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Avatar::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `avatar.image` | `Avatar::Image` | `AvatarImage` |
| `avatar.fallback` | `Avatar::Fallback` | `AvatarFallback` |
| `avatar.badge` | `Avatar::Badge` | `AvatarBadge` |
| `avatar.group` | `Avatar::Group` | `AvatarGroup` |
| `avatar.group_count` | `Avatar::GroupCount` | `AvatarGroupCount` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

None. The component renders no other `Components::V2` component and no icon itself. Scenarios place lucide icons (`<icon:check>`, `<icon:plus>`) inside `AvatarBadge` / `AvatarGroupCount` as caller content, rendered by the harness through `Components::V2::Icon` like any child.

Scenario fixtures: image `src` values are inline data URIs (a 64x64 SVG for "loads", `data:image/png;base64,AAAA` for "fails") instead of the demo's `https://github.com/*.png`, so both harnesses load identically without network; the `example__avatar-demo` scenario keeps the demo's tree with those substitutions.

## Deviations

One structural deviation, recorded in `dev/port/deviations/avatar.json`:

- `Avatar::Image` (always) and `Avatar::Fallback` with `delay_ms` (until shown) are server-rendered inside an inert `<template>` placeholder at their JSX position, because a server-rendered page cannot "not render" an element and still know its attributes when the client later mounts it (React re-renders from props; Stimulus has no props). The template has no `data-slot`, no classes, renders nothing, is invisible to the accessibility tree and to the parity snapshot (`[data-slot]` nodes only; template content is not in the document). Once mounted, the DOM is identical to React's. Machine-readable entry: `{ "reason": "...", "allow_tokens": [], "allow_missing_tokens": [], "api": ["Avatar::Image / Avatar::Fallback(delay_ms:): unmounted parts are kept in an inert <template> placeholder (no data-slot) until the controller mounts them"] }`.
