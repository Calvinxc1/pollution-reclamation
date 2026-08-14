# Enforcement-Redesign Policy-Line Transition Prompt

Use this prompt when an already-governed agent should move from the baseline policy line to the `enforcement-redesign/<endpoint>/main` policy line.

This prompt is for transition, not first-time bootstrap. If the workspace has no `AGENTS.md` and no `.governance/` tree, use `governance-bootstrap-prompt.md` from literal branch `main` instead.

Transition downstream workspaces only from the selected target branch's `lab-governance/` tree. Never use this repository's `.governance/` tree as the source or an external reference for another workspace. Do not copy the target branch's concrete `lab-governance/status.yaml`; create or update downstream status from `lab-governance/templates/local-status.yaml`.

Target branch mapping:

```text
general -> enforcement-redesign/trunk/main
coding_agent -> enforcement-redesign/coding-agent/main
desktop_orchestrator -> enforcement-redesign/desktop-orchestrator/main
factorio_modding_agent -> enforcement-redesign/factorio-modding-agent/main
```

## Prompt

````markdown
Before doing substantive work, transition this already-governed workspace from Jason's baseline governance policy line to the enforcement-redesign policy line.

Use Jason's `ai-governance` repository as the source:

```text
gitea.infra.newedenhomestead.net:ai-projects/ai-governance.git
```

This is an enforcement-redesign policy-line transition. Do not update from `baseline/<endpoint>/main` branches unless Jason explicitly cancels or redirects the transition.

First, inspect the current local governance state without changing files:

- read `AGENTS.md`
- read `lab-governance/status.yaml` if present
- read `lab-governance/branch-descriptor.yaml` if present
- read `.governance/kind-routes.yaml` if present
- identify the current active governance branch, current active canon version, generalized canon version, source branch, and source commit when locally recorded

Confirm or ask for:

- the Jason-settled canonical agent name
- the agent kind
- the target enforcement-redesign branch from the mapping below
- whether local-only governance files should be preserved as-is or reconciled during the transition

Target enforcement-redesign branch mapping:

```text
general -> enforcement-redesign/trunk/main
coding_agent -> enforcement-redesign/coding-agent/main
desktop_orchestrator -> enforcement-redesign/desktop-orchestrator/main
factorio_modding_agent -> enforcement-redesign/factorio-modding-agent/main
```

Then:

1. Fetch or inspect `ai-governance`.
2. Verify the target enforcement-redesign branch exists.
3. Read `governance-bootstrap-prompt.md` from literal branch `main`, then read the target branch's `AGENTS.md`, `lab-governance/branch-descriptor.yaml`, and `lab-governance/governance-init.md`.
4. Copy or merge the target branch's `lab-governance/` product into this workspace, excluding the target branch's concrete `lab-governance/status.yaml`.
5. Preserve workspace-local files under `.governance/local/` unless Jason or explicit policy says to reconcile them.
6. Ensure `.governance/local/index.yaml` exists, using `lab-governance/templates/local-index.yaml` from the target branch when needed.
7. Create or update this workspace's `lab-governance/status.yaml` from `lab-governance/templates/local-status.yaml` so it records the target branch, target active canon version, target generalized canon version, source repository, source branch, source commit when known, verification date, and any unresolved reconciliation notes.
8. Re-read this workspace's resulting `AGENTS.md`, `.governance/policies/universal.yaml`, `.governance/policies/enforcement-model.yaml`, `.governance/task-map.yaml`, any `.governance/kind-routes.yaml`, and `.governance/local/index.yaml` when present. These are this workspace's seeded files, not this repository's `.governance/` files.
9. Compare the pre-transition status, new local status, target branch descriptor, and old branch or version evidence. Report conflicts instead of silently reconciling them.

Stop and ask Jason before mutating local governance if:

- the canonical agent name is missing or disputed
- the agent kind is unknown
- the target enforcement-redesign branch is ambiguous or missing
- local status conflicts with the target branch descriptor in a way that changes which branch should be consumed
- local-only governance files appear to override branch selection
- the workspace has uncommitted local governance edits whose owner is unclear

Close out with only:

- canonical agent name and agent kind
- previous governance branch and canon version, if known
- target enforcement-redesign branch and commit consumed, when known
- active and generalized canon versions after the transition
- local status path updated
- local status declared state
- local-only files preserved or reconciled
- unresolved reconciliation items and their owners
````
