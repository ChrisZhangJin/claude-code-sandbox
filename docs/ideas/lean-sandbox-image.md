# claude_sandbox: lean coding/DevOps agent image

## Problem Statement
How might we provision a coding+Go+DevOps agent's sandbox with everything it
needs on first boot, while carrying nothing it doesn't — optimizing for
registry storage and rebuild-iteration speed, not pull latency?

## Recommended Direction
Direction B + version pinning. Take the two free structural fixes (docker.tgz
dead layer, node duplication) to erase the 2.5→2.6 regression, move the two
Python LLM libs to on-demand install (they don't match the actual workload),
and pin the volatile npm globals so the big layer stops busting cache on every
rebuild. Keep Go, docker+compose, and CodeGraph — all load-bearing for the
stated workload. Result: 1.53 GB (from 1.86 GB), faster rebuilds, cross-tag
layer reuse.

## Outcome (2026-07-16)
Built `claude_sandbox:2.6-slim` = **1.53 GB** (−330 MB vs 2.6, −130 MB vs 2.5).
- node-binary dedup: npm-globals layer 671 → 543 MB
- fastmcp/langsmith → optional: apt+pip layer 525 → 408 MB
- docker.tgz builder-extract: 86 MB `/tmp` layer eliminated
- npm globals pinned: claude-code 2.1.211, codegraph 1.4.1, typescript 7.0.2,
  typescript-language-server 5.3.0, get-shit-done-cc 1.42.3
Smoke test green: claude/docker/compose/go/uv/codegraph/tsc/tsls all work,
no broken symlinks, fastmcp correctly absent, 136 skills intact.

## Key Assumptions to Validate
- [x] fastmcp/langsmith not needed at boot — moved to install-optional-tools.sh
- [ ] CodeGraph hook degrades gracefully in repos with no .codegraph/ dir
      (no per-prompt errors) — test in a fresh repo.
- [ ] Pinning strands you on a stale Claude Code unless bumped — decide cadence.

## MVP Scope
In:  docker.tgz→builder-extract; COPY only lib/node_modules + rebuilt bin
     symlinks (not all /usr/local); fastmcp+langsmith→install-optional-tools.sh
     (keep uv); pin npm globals + GSD.
Out: touching CodeGraph, Go, docker/compose, or the skill set.

## Not Doing (and Why)
- Dropping CodeGraph — wired as UserPromptSubmit hook + MCP server; 227 MB but
  load-bearing, and ripping it out is settings.json surgery with feature loss.
- Dropping docker compose — DevOps is a stated core workload.
- Dropping Go toolchain — primary language; 206 MB is earned.
- Distroless/alpine base — node:24-slim is fine; the win was in duplication +
  discretionary libs, not the base.
- Pull-latency optimization — registry is LAN; not the real constraint.

## Open Questions
- Version-bump cadence now that npm globals are pinned? (monthly? on release?)
- Retag 2.6-slim → 2.6, delete rc1, publish to registry — now or after review?
