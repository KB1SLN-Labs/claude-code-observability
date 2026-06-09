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

## Task execution

For each task, first assess whether it can be split into independent chunks. If it can, break the work across parallel agents instead of doing everything sequentially.

## Project context

This is a pure infrastructure/config project — no application code. Changes are made locally and pushed to GitHub, then pulled and applied on the K8s cluster (`clus01-master`). See `.claude/memory/project-overview.md` for full context.

Personal overlays (Dynatrace, local Docker Compose) are gitignored. See `.claude/memory/dynatrace-fanout.md` before making any changes to the Helm chart or OTel collector config.

## Compaction / Context Recovery Protocol

Claude must not rely on conversation history, auto-compaction summaries, memory, or prior chat context alone for active APT work.

Before any manual `/compact`, anticipated automatic compaction, long-running task continuation, handoff, sub-agent delegation, or context-heavy investigation, write or update:

```text
D:\kb1slnlabs-projects\claude-code-observability\_ai_recovery\CURRENT_SESSION.md
```

Use narrower recovery files when the work is isolated:

```text
D:\kb1slnlabs-projects\claude-code-observability\_ai_recovery\CURRENT_APP_SESSION.md
D:\kb1slnlabs-projects\claude-code-observability\_ai_recovery\CURRENT_COMMERCIAL_SESSION.md
```

The recovery file is operational state, not source code. Do not create, edit, stage, commit, mirror, sync, or package repo-tracked recovery files unless the current issue explicitly authorizes documentation changes.

### Recovery file must include

```text
RECOVERY_VERSION:
LAST_UPDATED_UTC:
SESSION_OWNER:
TASK_SCOPE:
CURRENT_ISSUE:
CURRENT_MODE_OR_CHECKPOINT:
CURRENT_REPO_CONTEXT:
  app_operational_repo:
  app_codex_repo:
  commercial_repo:
  current_branch_by_repo:
  current_head_by_repo:
  dirty_state_by_repo:
ACCEPTED_PRIOR_EVIDENCE:
  last_accepted_result:
  last_accepted_artifacts:
  manifest_or_file_list:
  validation_status:
  helper_summary_paths:
OPEN_BLOCKERS:
DECISIONS_MADE:
EXPLICIT_OPERATOR_APPROVALS:
EXPLICIT_NON_ACTIONS:
  - no unapproved source edits
  - no main-branch source edits
  - no unapproved commit/stage/mirror/finish/sync/deploy/restart/live validation
  - no unapproved Linear/GitHub/config/profile/credential mutation
NEXT_SAFE_CHECKPOINT:
UNKNOWN_VALUES:
  - value:
    required_discovery_method:
COMMANDS_RUN_THIS_SESSION:
  - command_summary:
    mutation_class:
    result:
FILES_CHANGED_OR_CREATED:
  - path:
    tracked_or_untracked:
    reason:
    approval:
ROLLBACK_OR_CLEANUP_NEEDS:
RECOVERY_INSTRUCTIONS:
  - read this file first after compaction or session resume
  - verify live repo, helper, and Linear state before acting
  - treat stale or conflicting recovery data as evidence to re-verify, not authority
```

### Update triggers

Update the recovery file after:

1. any PASS / FAIL / BLOCKED checkpoint;
2. any file mutation;
3. any branch, commit, tag, mirror, sync, deploy, restart, cleanup, or Linear-status decision;
4. any operator approval or rejection;
5. any new blocker or RCA finding;
6. before `/compact`;
7. before launching a sub-agent;
8. after receiving a sub-agent result;
9. before ending the session.

### After compaction or session resume

Immediately read:

```text
D:\kb1slnlabs-projects\claude-code-observability\_ai_recovery\CURRENT_SESSION.md
```

Then verify current live state before acting:

1. repo branch, HEAD, and dirty status;
2. relevant Linear issue state;
3. helper-native summary/evidence;
4. current approved manifests and blockers;
5. whether the recovery file is stale or conflicts with live evidence.

If any required value is missing, stale, or contradictory, mark it `UNKNOWN` and use the correct helper, repo inspection, Linear read, or operator question to discover it. Do not infer it from memory.

### Sub-agent / task delegation rule

When using sub-agents for broad research, large log review, multi-file inspection, repo archaeology, or parallel investigation, Claude must preserve context explicitly.

Sub-agents do not reliably inherit the full parent conversation, accepted decisions, operator approvals, or current recovery state. The parent agent must provide the sub-agent with all required context.

Before launching a sub-agent, include:

```text
CURRENT_ISSUE:
TASK_SCOPE:
REPO_PATHS:
CURRENT_BRANCH_HEAD_STATUS:
ACCEPTED_PRIOR_EVIDENCE:
APPROVED_MANIFEST:
EXPLICIT_OPERATOR_APPROVALS:
EXPLICIT_NON_ACTIONS:
KNOWN_BLOCKERS:
UNKNOWN_VALUES_TO_DISCOVER:
FILES_OR_PATHS_TO_INSPECT:
OUTPUT_REQUIRED:
```

The sub-agent must return a compact result suitable for writing into:

```text
D:\kb1slnlabs-projects\claude-code-observability\_ai_recovery\CURRENT_SESSION.md
```

Sub-agent results are evidence, not authority. After a sub-agent returns, the parent agent must verify any safety-critical repo, Linear, helper, manifest, branch, HEAD, tag, approval, or blocker facts before mutation.

Do not let a sub-agent perform source edits, staging, commits, mirror operations, finish/sync, deploy, restart, live validation, Linear/GitHub mutation, cleanup, recovery mutation, config/profile/credential mutation, or trust broadening unless the current task explicitly authorizes that exact action and the parent prompt includes the exact approved manifest and stop boundaries.

If the sub-agent discovers missing or contradictory facts, record them as `UNKNOWN` or `BLOCKED` in the recovery file instead of guessing.

### Optional compact instruction

When manually compacting, use:

```text
/compact Preserve active APT task state only. Keep: current issue, mode/checkpoint, repo paths, branches, HEADs, dirty state, accepted evidence, approved manifests, operator approvals, non-actions, blockers, unknowns, exact next checkpoint, and recovery file path D:\kb1slnlabs-projects\claude-code-observability\_ai_recovery\CURRENT_SESSION.md. Drop long logs and repeated narrative. After compaction, first read the recovery file and verify live repo/helper/Linear state before acting.
```
