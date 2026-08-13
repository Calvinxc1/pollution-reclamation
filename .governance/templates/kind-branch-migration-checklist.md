# Kind Branch Migration Checklist

Use this checklist when aligning a workspace or repository to a target governance kind branch.

This checklist is intentionally version-agnostic. Do not hard-code today's canon versions into downstream work. Read the target branch descriptor, target version log, or Jason's explicit instruction, then verify the migrated workspace records those current target values consistently.

## Target

- Identify the target governance branch.
- Identify the target branch's current `canon_version`.
- Identify the target branch's declared parent branch and parent `canon_version`, when the target branch has a parent.
- Identify the source governance repository and source commit or tag used for the migration, when available.

## Entry Points

- Confirm `AGENTS.md` exists and points agents to the workspace's `.governance/` tree.
- Confirm `AGENTS.md` allows loading `.governance/task-map.yaml`.
- Confirm `AGENTS.md` allows loading `.governance/kind-routes.yaml` when present.
- Confirm `AGENTS.md` allows loading `.governance/local/index.yaml` when present.

## Canon Governance

- Confirm `lab-governance/branch-descriptor.yaml` matches the selected target branch and target `canon_version`.
- Confirm the branch descriptor records the target branch's current parent branch and parent `canon_version`, when applicable.
- Confirm `.governance/task-map.yaml` routes to workspace-local `.governance/...` paths.
- Confirm `.governance/kind-routes.yaml` exists when the target branch uses kind routing.
- Confirm kind routes point to the intended `.governance/...` policy files.
- Confirm every routed policy or process file exists.
- Confirm branch descriptors do not contain workspace-local status fields; local status belongs under `.governance/local/`.

## Local Governance

- Confirm `.governance/local/index.yaml` exists as the local governance pointer when the workspace has local status, workflow facts, overlays, or deviations.
- Confirm `lab-governance/status.yaml` exists when the workspace participates in portable local governance status.
- Confirm local status records the canonical agent name, active governance branch, active `canon_version`, and parent or generalized `canon_version` using the current target values.
- Confirm local status records runtime surface, gate state, granted capability authority, repository trust state when applicable, managed requirements state when applicable, and projection state when applicable.
- Confirm an ungated runtime surface has no production or protected mutation authority unless Jason explicitly accepted a named residual risk.
- Confirm any Codex workspace that relies on repo-local `.codex/config.toml` is trusted before relying on `developer_instructions`.
- Confirm any generated runtime projection, Codex TOML artifact, Codex `.rules` file, or managed requirements artifact is current for the recorded source branch and `canon_version`.
- Confirm workspace-local workflow facts, overlays, deviations, and notes remain local policy or local metadata rather than being folded into generalized branch policy.
- Confirm local workflow or overlay facts are filled from the current workspace, not copied from another repository.

## Path And Publication Boundaries

- Confirm downstream workspaces do not rely on active `lab-governance/...` paths unless the workspace is intentionally the source governance repository.
- Confirm a top-level `lab-governance/` tree is absent from downstream repositories unless Jason explicitly wants that repository to maintain generalized governance.
- For intentionally local-only governance, confirm the local files are excluded from publication or commit through the workspace's chosen local mechanism.
- Local-only fork governance may note that a workspace is an upstream fork and keep fork-specific rules local, but the actual fork-specific policy must live in that workspace's local governance files.

## Verification

- Validate changed YAML files.
- Validate generated TOML artifacts before distribution.
- Validate generated `.rules` artifacts with inline assertions and any available Codex rules validation command before distribution.
- Scan changed governance files for conflict markers.
- Verify the repository branch, local path, or other source of truth that will be used for closeout.
- Report the target branch, target `canon_version`, parent `canon_version` when applicable, files changed, validation performed, commit or no-commit reason, and remaining uncertainty.
