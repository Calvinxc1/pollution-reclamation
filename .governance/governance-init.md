# Governance Initialization

Purpose: give a new agent enough procedure to initialize governance before doing substantive work.

This document is a setup guide, not a replacement for policy. The operative contract remains the repository or workspace governance files the agent loads during initialization.

For a downstream workspace, the seed and update source is always the selected branch's `lab-governance/` tree from Jason's `ai-governance` repository. This repository's `.governance/` tree is the Governance Agent's own uniform operating layer and must not be copied, merged, diffed against, or used as an external source for another workspace.

Do not copy this repository's concrete `lab-governance/status.yaml` into a downstream workspace. That file is source-branch maintainer status for this repository. Downstream workspaces create or update their own `lab-governance/status.yaml` from `lab-governance/templates/local-status.yaml`.

## Two-Tree Update Model

- In a downstream workspace, `.governance/` is the active local governance tree the agent loads and obeys.
- In `ai-governance`, the selected endpoint branch's `lab-governance/` tree is the source product used to seed or update that downstream `.governance/` tree.
- Never use `ai-governance`'s own `.governance/` tree as the downstream source. It governs this repository's Governance Agent only.
- `lab-governance/status.yaml` in the downstream workspace is local status metadata, not the active local policy tree.

## Startup Order

1. Find the workspace governance entrypoint.

   Start with `AGENTS.md` at the workspace root. If no workspace-local `AGENTS.md` exists, ask Jason or the orchestrating agent where governance is mounted before doing substantive work.

2. Load the always-load policy files named by the entrypoint.

   Follow the entrypoint exactly. Different policy lines may name different always-load files. Use `.governance/` paths for an active workspace copy, or the corresponding `lab-governance/` paths only when initializing from the generalized lab governance source.

3. Load task-specific policy through the task map.

   Use `.governance/task-map.yaml` in an active workspace copy. Use `lab-governance/task-map.yaml` only when bootstrapping from the generalized source or maintaining generalized governance itself.

   If the task asks the agent to join, monitor, coordinate in, or close an Althing or other live agent room, select the `live_agent_coordination` route before joining the room.

4. Load local governance when present.

   If `.governance/local/index.yaml` exists, read it after the base lab/canon governance. Treat it as the workspace-owned pointer into local governance. The lab governance contract prescribes only this pointer file and not the internal structure of `.governance/local/`.

   Local governance is the layer above the base lab/canon governance for that workspace. Explicit task overrides are the top layer and may override both base and local governance only for the declared one-shot operation.

5. Check branch or kind routing.

   If the active governance branch has a `.governance/kind-routes.yaml` file, load it after the task map. Channel-trunk-general governance does not require a kind-routes file.

6. Prompt for the canonical agent name.

   Ask Jason or the orchestrating agent for the agent's Jason-settled canonical name before version reconciliation or substantive work. Use a direct prompt:

   ```text
   What canonical agent name should I use for this workspace?
   ```

   If `lab-governance/status.yaml` already names a canonical agent, report that value and ask Jason to confirm or correct it. Do not infer the canonical name from the repository name, hostname, model backend, task role, or prior chat label.

7. Check local governance status.

   Read `lab-governance/status.yaml` when present. This is the universal local status path for a governed workspace. It records the agent's canonical name, kind, active governance branch, current active canon version, current generalized canon version, source, runtime surface, granted authority, and locally attested status.

   If the file is missing during initialization or update, create it from `lab-governance/templates/local-status.yaml`. Fill only locally attested values and use `null` for unknowns. The local status file is the authoritative portable report.

8. Verify runtime surface and authority state.

   Record the active `runtime_surface`, `runtime_surface_gate_state`, `granted_capability_authority`, repository trust state where applicable, managed requirements state where applicable, and projection state where applicable.

   If the runtime surface is ungated, confirm that production and protected mutation authority are absent or externally mediated before substantive work that would use that authority. If the surface appears to hold protected authority without a tested gate or capability removal, stop and route the decision to Jason.

   On Codex surfaces that rely on repository `.codex/config.toml`, verify that the repository is trusted before relying on repo-local `developer_instructions`. An untrusted repository may still load `AGENTS.md` while silently skipping repo `.codex/` config, so it can appear governed without the full load contract.

   On Codex surfaces that rely on generated TOML, `.rules`, or managed requirements artifacts, verify that the artifacts are present, current for the recorded canon version, and validated before treating their controls as active.

9. Apply the startup version rule.

   If current governance version equals target, continue silently. If current is behind target, report only:

   ```text
   Current: <version>
   Target: <version>
   Update before proceeding? yes/no
   ```

   Then wait for Jason's answer before substantive work.

   If Jason answers yes, use `governance-bootstrap-prompt.md` from the root of literal branch `main` of the ai-governance repository as the canonical bootstrap/update prompt. Follow that prompt for explicit target policy-line selection, source branch selection, local governance update, local status update, and reconciliation reporting.

10. Declare loaded governance if action will follow.

   Before edits, connector actions, or other substantive work, perform the final action verification required by execution-control: state the intended action, affected files or systems, expected risk tier, and validation plan, then wait for Jason's approval unless his immediately preceding message already approved that exact verification.

## Althing And Live Room Join Checklist

Before joining an Althing or other live agent room:

- Load the `live_agent_coordination` route and the room transport's available connector boundaries.
- Know the room identifier, canonical agent name, assigned or expected role when one was provided, and any Jason-designated runner, closer, or liaison.
- Announce presence in one line after joining.
- Check current presence if the transport supports it.
- Participate in the preliminary coordination exchange before substantive room work begins.
- Keep cursor-aware polling active while the room remains active.
- Do not leave until suspended, closed out, or dismissed by name.

## Installing Governance Into A New Workspace

Use this sequence when an agent workspace does not yet have a local governance copy.

1. Identify the intended agent kind and source branch.

   First ask for the workspace's canonical agent name. If local status already exists, use it only as candidate evidence and ask Jason to confirm or correct the name before choosing a governance branch or kind.

   Use the target policy line explicitly named by Jason, the orchestrating agent, or confirmed local status. If the target policy line is missing or disputed, ask whether the workspace should use `baseline` or `enforcement-redesign` before changing files. Then choose the current mapped `/main` endpoint branch for the intended agent kind within that confirmed policy line unless Jason explicitly redirects the workspace to another branch.

2. Copy the selected branch's `lab-governance/` product into the workspace.

   A governed workspace should have a local `.governance/` tree and an `AGENTS.md` entrypoint seeded or updated from the selected branch's `lab-governance/` tree. Never seed or update a downstream workspace from this repository's `.governance/` tree. Exclude the selected source branch's concrete `lab-governance/status.yaml`; downstream status is generated from the status template and filled with locally attested values. Do not point ordinary workspace agents directly at this repository's `.governance/` tree unless Jason explicitly chooses a centralized mount model for that workspace.

3. Preserve the entrypoint contract.

   `AGENTS.md` should stay thin. It should name the active governance directory, precedence order, always-load file, and routing files.

4. Create or update the local status file.

   Ensure `lab-governance/status.yaml` exists. Start from `lab-governance/templates/local-status.yaml`. Fill only locally attested values for the downstream workspace. Use `null` rather than invented data, and do not reuse this repository's source-branch status values.

5. Record runtime surface and capability authority.

   Fill runtime-surface fields from observed local state. Do not infer that a runtime gate works from documentation. If a required value is unknown, leave it `null` or mark it unknown rather than inventing it.

   For Codex workspaces that rely on repo `.codex/config.toml`, verify repository trust before relying on `developer_instructions`. For workspaces that rely on managed requirements, verify the managed file is present and current. For workspaces with generated projections, verify the projection stamps match the source branch and canon version.

6. Create or preserve the local governance index.

   Ensure `.governance/local/index.yaml` exists. Start from `lab-governance/templates/local-index.yaml` if needed. The index is a loose pointer into local governance; do not prescribe the rest of `.governance/local/` from lab governance.

7. Reconcile local status with source governance state.

   Compare local status with the selected source branch descriptor and old branch or version evidence. If records disagree, do not silently choose one. Treat obsolete branch names and old status shapes as migration evidence rather than authoritative blockers unless they create a real policy-line, identity, or local-governance conflict. Mark the local status as `behind`, `drifted`, or `unknown` as appropriate, then route the decision to Jason through the active human liaison.

8. Review local governance conflicts.

   After seeding or updating base governance into the downstream `.governance/` tree, load every local governance file reachable from `.governance/local/index.yaml` and compare local governance against the newly seeded canonical governance. Surface conflicts, duplicated rules, obsolete local overrides, and local rules that now overlap with canonical rules. Local governance wins operationally over canonical governance unless Jason or explicit local policy says otherwise, but conflicts and redundancies must still be reported.

9. Confirm no secrets were introduced.

   Governance files may contain paths, branch names, canon versions, and provenance references. They must not contain tokens, API keys, private credentials, or recoverable secrets.

## Minimum Files For A Governed Workspace

The normal local workspace shape is:

```text
AGENTS.md
.governance/README.md
.governance/task-map.yaml
lab-governance/branch-descriptor.yaml
.governance/policies/universal.yaml
.governance/policies/*.yaml
.governance/processes/*.yaml
.governance/overrides/*.yaml
.governance/local/index.yaml
lab-governance/status.yaml
```

The downstream workspace's `.governance/` tree is its local seeded copy derived from the selected branch's `lab-governance/` product. It is not copied from this repository's `.governance/` operating layer.

Kind branches may add:

```text
.governance/kind-routes.yaml
```

This `ai-governance` repository also maintains:

```text
lab-governance/
canon-version-log/
```

Ordinary downstream repositories should not infer that they need to maintain those generalized governance maintenance trees locally.

## Task Briefs

For substantial delegated work, use `lab-governance/templates/task-brief.md`. Describe the outcome and bounds; prescribe only the protocol needed to protect the work.

## Acceptance Checklist

Governance is initialized when all of the following are true:

- The agent knows which governance entrypoint governs the workspace.
- The agent has asked for, confirmed, or explicitly reported as missing its Jason-settled canonical name.
- The agent has loaded `AGENTS.md` and the always-load policy.
- Additional policy was loaded only through the task map and any kind route.
- Local governance was loaded through `.governance/local/index.yaml` when present.
- The agent has checked `lab-governance/status.yaml` and reconciled it against source governance state when possible.
- The agent has recorded or explicitly marked unknown the active runtime surface, gate state, granted capability authority, repository trust state when applicable, managed requirements state when applicable, and projection state when applicable.
- Any protected authority on an ungated runtime surface has been removed, externally mediated, or routed to Jason before use.
- Any repo-local Codex `developer_instructions` dependency is backed by verified repository trust.
- Any version mismatch was reported using the minimal startup version rule.
- The agent can name the active canon version it believes it is consuming, or can clearly state that the value is unknown.
- The agent has not written secrets into governance files.
- Jason remains the final arbiter for unresolved human-owned decisions.

## Failure Modes

Stop and ask before substantive work when:

- No governance entrypoint can be found.
- The Jason-settled canonical agent name is missing or disputed.
- The active branch, kind, or target canon version is ambiguous.
- Local status and source governance state disagree.
- Runtime surface, gate state, repository trust, managed requirements, projection freshness, or granted authority state is unknown and the requested work depends on it.
- The requested work would use production or protected mutation authority on an ungated surface.
- Local governance conflicts with updated canonical governance in a way that changes whether the agent may act.
- A policy conflict changes whether the agent may act.
- The requested task depends on accepting a draft governance rule as ratified.

When blocked, report the exact missing fact or conflict. Do not continue by treating silence, draft text, or execution permission as acceptance.
