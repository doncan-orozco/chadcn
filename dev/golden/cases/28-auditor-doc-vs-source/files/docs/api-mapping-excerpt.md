# api-mapping.md (excerpt, project doc)

`render_as_child` merges the parent part's attributes into the child's with exactly Radix `mergeProps` semantics:
child props win, `class` is joined and conflict-resolved (`cn(slot, child)`), `data-action` descriptors are concatenated,
`style` is merged.
