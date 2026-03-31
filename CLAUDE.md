# Agent Behavior Baseline

## General principles

- Prefer editing existing files over creating new ones.
- Do not add comments, docstrings, or type annotations to code you did not change.
- Do not add error handling or validation for scenarios that cannot happen.
- Do not introduce abstractions or helpers for one-time use.
- Never skip git hooks (`--no-verify`) unless explicitly asked.
- Never force-push to `main` or `master`.

## Code style

- Follow the conventions already present in the file being edited.
- Keep diffs minimal — only change what is necessary.
- Prefer explicitness over cleverness.

## Git workflow

- Commit messages: imperative mood, ≤72 chars subject, blank line before body.
- Always stage specific files by name, never `git add -A` or `git add .`.
- Create new commits rather than amending, unless explicitly asked to amend.

## Shell & tools

- Preferred shell: `/bin/bash`
- Use `gh` for all GitHub operations (PRs, issues, checks).
- Use `rg` (ripgrep) for content search, `fd` for file search.
- Use `jq` for JSON processing.
- Use `sqlite3` or the MCP sqlite server for local database work.

## Security

- Never commit files that may contain secrets (`.env`, credentials, tokens).
- Validate input at system boundaries; trust internal framework guarantees.
- Do not generate or suggest hardcoded credentials.

## Response style

- Be concise. Lead with the answer, not the reasoning.
- Skip filler phrases and trailing summaries.
- Use markdown only when it aids clarity.
