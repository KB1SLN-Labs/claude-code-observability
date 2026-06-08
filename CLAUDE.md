# Project Instructions — claude-code-observability

## Memory

All project-specific memory for this project lives in `.claude/memory/` within this directory. Do NOT write project memory to the global `~/.claude/projects/` directory.

At the start of every session:
1. Read `.claude/memory/MEMORY.md` to load the memory index
2. Read any memory files that are relevant to the current task

When saving new memories or updating existing ones during a session:
- Write to `.claude/memory/` in this project directory
- Keep `.claude/memory/MEMORY.md` up to date as the index
- Do NOT write to or sync with the global `~/.claude/projects/` directory — this project is self-contained and other projects have no need for this context

## Project context

This is a pure infrastructure/config project — no application code. Changes are made locally and pushed to GitHub, then pulled and applied on the K8s cluster (`clus01-master`). See `.claude/memory/project-overview.md` for full context.

Personal overlays (Dynatrace, local Docker Compose) are gitignored. See `.claude/memory/dynatrace-fanout.md` before making any changes to the Helm chart or OTel collector config.
