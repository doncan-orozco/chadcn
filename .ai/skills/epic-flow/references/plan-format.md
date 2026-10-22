# Plan file and issue body

`/epic-plan` writes `tmp/epic/<slug>/plan.json`, checks it with `plan-check`, shows it to the human, and only then creates the issues with `plan-apply`.

```json
{
  "epic": { "slug": "chadcn", "title": "Extract Components::V2 into the chadcn gem", "body": "scope, non-goals, decisions already made, links" },
  "items": [
    {
      "key": "skeleton",
      "title": "Gem skeleton with standalone test harness",
      "wave": 0,
      "owns": ["*.gemspec", "Gemfile", "test/test_helper.rb"],
      "blocked_by": [],
      "stage": "plan",
      "priority": 10,
      "goal": "One paragraph: what exists when this is done and why.",
      "gates": ["bundle exec rake test", "ruby .claude/scripts/gem/coupling_check.rb --gem-dir ."],
      "acceptance": ["gem tests run without the host app", "no host constant is visible from the gem"],
      "context": "optional: links, prior decisions, pitfalls"
    }
  ]
}
```

## Rules `plan-check` enforces

- `epic.slug` is kebab-case; `epic.title` present; at least one item.
- Every item has `key` (unique), `title`, `wave`, `owns` (globs, non-empty), `goal`, `gates` (non-empty list of shell commands: the judge), `acceptance` (non-empty).
- `blocked_by` holds keys of other items; the blocker's `wave` is strictly lower; no cycles.
- Two items that can run at the same time (neither depends on the other, directly or transitively) must not own overlapping files. Ownership overlap is decided on the literal prefix before the first wildcard.
- `stage` defaults to `plan` and must be a known stage.

## Planning guidance

- Waves: wave 0 is whatever everything else needs (decisions, skeleton, tooling); a serial migration step gets its own wave; fan-out waves hold independent slices.
- Foundation items are blockers; consumers never start before they merge (epic-flow R8).
- A gate is a command a worker can run unattended and whose exit code means pass or fail. "Looks right" is not a gate; if nothing can judge it, add the script that can.
- Keep items sized for one session of a few hours; split when Owns spans unrelated areas.

## Issue body produced by `plan-apply`

```
## Goal
## Owns
## Blocked by      (- #N (key))
## Gates (a stage advances only when these are green, run by the worker)
## Acceptance      (- [ ] ...)
## Context         (optional)
<!-- work-item {"epic":..,"wave":..,"owns":[..],"blocked_by":[numbers],"priority":..,"key":..} -->
```

Labels: `epic:<slug>`, `stage:<stage>`, `wave:<n>`; the root issue has `epic-root`. Later labels: `claimed`, `blocked`, `needs-human`.
