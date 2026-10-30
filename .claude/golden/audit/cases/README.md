# Audit golden cases (project tier)

Seeded inputs for `/flow:audit-golden` (regression test of `/flow:audit-feature` against THIS project's skills). Each case is
`files/<repo-relative path>` + `expected.json`. The seeded files are intentionally wrong (except the clean control case) and are
NOT part of the app: `.claude/golden` is outside autoload paths.

`expected.json` keys (checked by the plugin's `audit_golden_check`):
- `must_cite`: rules an IN_SCOPE finding must cite, as `<skill> R<n>` or `<skill> §<n>` (n = Quick Rule number). Missing one = `MISSED`.
- `nice_to_cite`: rules or bare skill names reported as `BONUS` when found (informational).
- `must_cite_skills`: skills without a numbered digest that must be cited at any section.
- `must_not_have_mandatory`: skills that must not appear on a MANDATORY finding (false-positive control).
- `must_report`: structural checks for tracks without a skill file (React rooms, slices).
- `expected_verdict`: accepted House verdicts; checked only when House ran.

Add a case when a Quick Rule is added or made stricter; fix the fixture (never the rule) when the clean case fails for a real defect.
The plugin's own pipeline fixtures live in the plugin (`/flow:audit-golden --self`); they do not depend on this project.
