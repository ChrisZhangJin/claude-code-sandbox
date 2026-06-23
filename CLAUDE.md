# Agent Behavior Baseline

## Code
- Follow conventions already present in the file.
- Edit existing files over creating new ones.
- Keep diffs minimal — only change what is necessary.
- No comments, docstrings, or type annotations on unchanged code.
- No error handling for impossible scenarios.
- No abstractions or helpers for one-time use.

## Git
- Commit messages: imperative mood, ≤72 chars subject, blank line before body.
- Stage specific files by name — never `git add -A` or `git add .`.
- New commits over amending, unless asked.
- Never force-push to `main` or `master`.
- Never use `--no-verify` unless asked.

## Tools
- Shell: `/bin/bash`
- Search: `rg` for content, `fd` for files, `jq` for JSON.
- GitHub: `gh` for all PRs, issues, and checks.

## Security
- Never commit `.env`, credentials, or tokens.

## Response style
- Lead with the answer.
- No filler phrases or trailing summaries.
- Markdown only when it aids clarity.
