---
description: Free an item that a session abandoned or hold, so another session can take it. Your own claims by default; a human can force-release any claim.
argument-hint: "<item-number> --epic <slug> [--force]"
allowed-tools: Bash(ruby:*)
---

# /work-release

Arguments: $ARGUMENTS
1. Without `--force` (you hold the item): `ruby .claude/scripts/epic/work_board.rb session` for your id, post a `handoff` note saying what is done and what is left (`ruby .claude/scripts/epic/work_board.rb comment N --epic S --session ID --type handoff --body "..."`), then `ruby .claude/scripts/epic/work_board.rb release N --epic S --session ID`.
2. With `--force` (a session died or is unreachable): confirm with the human that the other session is really gone, then `ruby .claude/scripts/epic/work_board.rb release N --epic S --force`. The branch and worktree of the old session stay untouched; tell the next worker to read the item's last `handoff` and continue from that branch if it exists.
3. Print the new state with `ruby .claude/scripts/epic/work_board.rb show N --epic S`.
