---
name: naming-conventions
description: "Domain-language naming rules for classes, methods and variables. Use when naming or renaming any new class, method, variable, operation, route or translation key in the Papyro codebase."
---

# Naming Conventions

## Quick Rules

Cite as `naming-conventions R<n>`. Detail and examples follow below / in references/.

R1. **Domain vocabulary.** Class, method and variable names use domain terms, not technical implementation terms (`Roster`, not `UserList`). → detail: Core Principle / Classes and Types
R2. **No stuttering.** Class and file names never repeat the namespace or type (`Published`, not `PublishedQuery`). → detail: Classes and Types
R3. **Domain types over primitives.** Compound domain concepts get their own type (`Money` with currency and amount) instead of raw String/Float/Hash. → detail: Classes and Types
R4. **Methods name the outcome.** Methods are named for what they accomplish (`within_enrollment_period?`), not how (`check_date_range`). → detail: Methods
R5. **Domain verbs for commands.** Command methods use domain verbs (`enroll`, `publish`, `archive`), not persistence verbs (`save`, `insert`, `update`). → detail: Methods
R6. **Predicates end in `?`.** Boolean methods end in `?` and read as domain assertions; avoid negated names (`active?`, not `not_expired?`). → detail: Methods / Avoid / Ruby-Specific Guidance
R7. **Bang only with counterpart.** `!` methods exist only when a safe non-bang counterpart exists (`publish` vs `publish!`). → detail: Ruby-Specific Guidance
R8. **Domain variable names.** Variables and iterators carry the domain term (`recipient`, `enrollment_fee`, `questions.each do |question|`), not `item`, `data`, `result`, `obj` or `date2`. → detail: Variables and Parameters / Avoid
R9. **Booleans read as assertions.** Boolean variables and parameters are named like `allow_retakes` or `requires_approval`, not `flag` or `bool_val`. → detail: Variables and Parameters
R10. **No cryptic abbreviations or suffixes.** No `usr`, `cfg`, `mgr`, `tmp`, and no `_hash`/`_array`/`_list` suffixes unless the structure is the domain concept. → detail: Avoid
R11. **Keyword args when ambiguous.** Use keyword arguments when two or more arguments share a type and order is not self-evident (`enroll(user: user, course: course)`). → detail: Method Arguments and Keyword Parameters
R12. **Constants and casing.** Constants are `SCREAMING_SNAKE_CASE` domain values; classes and modules are `PascalCase`; everything else is `snake_case`. → detail: Ruby-Specific Guidance

## Core Principle
Code should read like domain discussion. A casual observer should not be able to tell whether people are talking about the code or the business domain. If a financial analyst can point at a screen and walk programmers through pricing logic line-by-line without switching vocabulary, the naming is right.

## Rules


### Classes and Types
- Name types after the domain concept they represent, not after their technical implementation.
- **Never repeat the namespace or type in the class or file name (no stuttering):**
  - Use `Published` (not `PublishedQuery`), `Body` (not `BodyValidator`), `Default`/`Show` (not `ArticlePresenter`/`ShowPresenter`).
- Prefer `Surname`, `Money`, `Currency`, `EnrollmentPeriod` over `String`, `Float`, `Hash`.
- Compound domain concepts get their own type: `Money` has a `Currency` and an `Amount`, not a raw float.
- Never expose implementation-level details in a class name: `UserList` is worse than `Roster`; `QuestionHashMap` is worse than `QuestionBank`.

### Methods
- Name methods after what they accomplish in the domain, not how they do it.
- A method that determines whether an enrollment is still valid is `active?` or `within_enrollment_period?`, not `check_date_range`.
- Predicate methods (`valid?`, `expired?`, `visible_to?`) read as assertions about the domain state.
- Command methods (`enroll`, `publish`, `archive`) use the domain verb, not the persistence verb (`save`, `insert`, `update`).

### Variables and Parameters
- Name variables after what they hold in the domain, not their type or role in an algorithm.
- Prefer `recipient` over `user`, `enrollment_fee` over `amount`, `due_date` over `date2`.
- Iterator variables in a collection loop should carry the domain term: `questions.each do |question|`, not `items.each do |i|`.
- Boolean variables and parameters read as domain assertions: `allow_retakes`, `requires_approval`, not `flag`, `bool_val`.

### Method Arguments and Keyword Parameters
- Prefer keyword arguments when two or more arguments share a type and the order is not self-evident.
- `enroll(user: user, course: course)` beats `enroll(user, course)` when both are objects.

### Library exception (gems that mirror an external API)
R1 (domain vocabulary) does not apply inside a library whose purpose is to reproduce an external, named API: for `chadcn` the shadcn/Radix vocabulary (`Dialog::Content`, `as_child`, `data-slot` names) IS the domain language and is kept 1:1 even where it would not be our choice. R2 (no stuttering), R4 to R12 (outcome-named methods, predicates, bang methods, variables, keyword arguments, casing) still apply. The gem's own helpers and internals follow the normal rules. See `ruby-gem-conventions`.

### Avoid
- Abbreviations that are not universal in the domain (`usr`, `cfg`, `mgr`, `tmp`).
- Technical suffixes that leak implementation (`_hash`, `_array`, `_list`) unless the data structure is itself the domain concept.
- Generic container names (`data`, `result`, `obj`, `thing`, `item`) outside of very narrow local scope.
- Negated names that force double-negation reading: `not_expired?` is harder to read than `active?`.

## Domain-Based Language in Practice

Bad — technical vocabulary leaks into names:
```ruby
def process_data(hash_map)
  hash_map.each do |k, v|
    update_record(k, v.to_f)
  end
end
```

Good — reads like domain conversation:
```ruby
def apply_price_adjustments(trade_adjustments)
  trade_adjustments.each do |instrument, adjustment|
    instrument.reprice(adjustment)
  end
end
```

Bad — type used instead of domain concept:
```ruby
salary = 4500.75          # float
end_date = "2026-06-30"   # string
```

Good — domain types with constraints and meaning:
```ruby
salary = Money.new(amount: 4500.75, currency: :usd)
contract_end = ContractDate.new("2026-06-30")
```

## Ruby-Specific Guidance
- Boolean predicate methods end in `?`: `enrolled?`, `published?`, `overdue?`.
- Destructive/mutating methods end in `!` only when a safe counterpart exists: `publish` vs `publish!`.
- Constants use `SCREAMING_SNAKE_CASE` and are named after the domain value: `MAX_ENROLLMENT_SIZE`, `DEFAULT_PASSING_SCORE`.
- Module and class names use `PascalCase`; all other names use `snake_case`.

## Questions to Ask Before Naming
1. If a domain expert reads this name, does it mean the same thing to them as it does to you?
2. Does the name carry its intent without requiring a comment?
3. Would renaming this reveal a missing domain concept that should be modeled explicitly?
4. Does the name say *what* it is, not *how* it is stored or processed?
