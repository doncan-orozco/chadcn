# Intentional host paths and `gem_check` (GEM_ESCAPES_ROOT)

Status: decided (epic phlex-shadcn-adoption-followups, item #206). Applies to `.claude/scripts/gem/gem_check.rb` and the `ruby-gem-conventions` skill.

## Problem

`GEM_ESCAPES_ROOT` (R1) rejects string literals such as `"app/assets/..."` in gem Ruby files outside the Rails integration files (`lib/**/engine.rb`, `railtie.rb`, `lib/generators/**`, `lib/tasks/**`), because a hard-coded host path is how a gem silently stops being standalone. The doctor (`lib/phlex/shadcn/doctor/**`) exists precisely to inspect host files, so it legitimately names `app/assets/tailwind/application.css` and the host `bundle` files. PR #187 passed the rule by building the path with `File.join("app", "assets", ...)`; #177 keeps the Sprockets manifest path in `lib/generators/phlex/shadcn/install/sprockets_manifest.rb`.

Two facts frame the choice:

- Generator files are already exempt (they are Rails integration files), so the generator case needs nothing new.
- The `File.join` form is an evasion of a regex, not a statement of intent: nothing marks the path as deliberate, the next author copies the trick into core code, and a reviewer cannot grep for it.

## Options

### A. Sanction the `File.join("app", "assets", ...)` form in the skill

- No tooling change.
- The rule keeps matching only a spelling; any file anywhere can dodge it the same way, so the gate stops being a gate for host paths.
- No scope: nothing says "doctor only"; no reason is recorded; not greppable. The convention would read "you may defeat the check by writing it differently".

### B. Narrow explicit allowlist in `gem_check` (chosen)

A marker on the same line, honored only in the doctor:

```ruby
DEFAULT_CSS = "app/assets/tailwind/application.css" # gem_check:allow GEM_ESCAPES_ROOT -- the doctor reads the host stylesheet
```

- exact rule id (only the hard-coded host path check of `GEM_ESCAPES_ROOT`; `require_relative` leaving the gem is never allowable);
- a reason after `--` is required, a bare marker does not count;
- scope: files matching `HOST_PATH_ALLOW_GLOBS` (`lib/phlex/shadcn/doctor/**/*.rb`); the marker anywhere else is inert and the literal still fails;
- the marker is the line's trailing comment and its reason holds no quotes, so marker text inside a string literal never counts;
- same line only, so the exemption cannot drift away from the literal it covers.

Costs: one constant and a few lines in the script, and the doctor files should be switched from `File.join` to the marked literal (follow-up; those files are outside this item).

## Decision

B. The point of the rule is that deliberate host knowledge is visible and bounded. A marker is greppable, carries a reason, is limited to the one directory whose job is to read the host, and is tested both ways (allowed in the doctor; the same literal elsewhere, unmarked, marked without a reason, marked for another rule, marker on another line, marker text inside a string, the root `doctor.rb` or another namespace's `doctor/`, or a `require_relative` escape still fail). Option A would keep the rule passing while removing what it protects.

`File.join` string-splitting, `%w[]` literals and similar spellings to evade the rule are not sanctioned anywhere. They are not findings (the script cannot see those spellings), so reviewers cite `ruby-gem-conventions R15` when they see it.

## Rollout

- `gem_check` still passes on main unchanged: the doctor's `File.join` forms never matched the rule, so no existing rule was weakened and no finding appears or disappears.
- Follow-up (shared note on #206): change `doctor/context.rb` (`DEFAULT_CSS`) and `doctor/checks/engine_bundle.rb` (`BUNDLE`) from `File.join(...)` to a marked literal, and `doctor/checks/stimulus.rb` (`FILES`, a `%w[]` host-path list the regex cannot see) to quoted, marked literals.

## Related: the process-wide state of `Phlex::Shadcn::Base`

The skill's R4 says "no global mutable state". Two process-wide objects in `Phlex::Shadcn::Base` are a recorded exception (skill `ruby-gem-conventions`, section Namespacing), under explicit conditions: pure, bounded, safe under threads, `@api private`, and holding no configuration or request state.

- The `Base#cn` result memo (PR #189): `CN_CACHE`, bounded by `CN_CACHE_LIMIT` (cleared when full), read and written only while holding `CN_CACHE_LOCK`, a `Mutex` created when `base.rb` loads.
- `Base.tw_merger` (item #242, PR #254): one default-configuration `TailwindMerge::Merger` in `TW_MERGER`, also created when `base.rb` loads. It is thread-safe through its own internal `LruRedux::ThreadSafeCache`, so it does not use `CN_CACHE_LOCK`.

All four constants (`TW_MERGER`, `CN_CACHE`, `CN_CACHE_LIMIT`, `CN_CACHE_LOCK`) are private constants of `Base`, not class-level instance variables: constants are looked up through inheritance, so every subclass shares the single instance on purpose and `Subclass.tw_merger` cannot see an empty per-class variable. Nothing is built lazily: a `||=` on first use can create two mergers or two locks when threads race. Outside `cn` and its helper `cn_cached`, the memo is reached only through `@api private` test hooks: `cn_cache` returns a frozen snapshot taken under the lock (never the live hash) and `clear_cn_cache` empties the memo under the lock. `test/phlex/shadcn/base_cache_test.rb` proves in a fresh process that exactly one merger is built at load and that racing first uses share it and the cache.

Earlier this note recorded `Base.tw_merger` as a lazy, unlocked memo with a revisit condition; that condition was met by #242 and nothing is left to revisit. A new memo that does not meet these conditions violates R4 and needs its own entry in the skill with a removal or revisit condition.
