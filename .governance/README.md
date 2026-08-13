# Lab Governance Layout

This directory contains the lab-wide governance rule set maintained by this repository.

These files are the general policy and process contract intended to propagate to the rest of the lab and to specialized agent branches.

This stable `/main` endpoint branch uses an enforcement-first governance model. High-stakes recurring failures should map to hard gates, cheap default paths, or detectors; prose-only fixes are tracked debt unless Jason accepts the residual risk. Bootstrap and update instructions live on literal branch `main` and require an explicit target policy line before selecting the mapped `/main` endpoint for the target agent kind.

This directory is the maintained governance product for this branch. It is not the active local operating layer for the Governance Agent working in this repository; that role belongs to the uniform `.governance/` tree.

The `enforcement-redesign/trunk/main` branch carries the experimental general contract for every agent kind. Secondary kind branches carry complete branch-local pictures after `enforcement-redesign/trunk/main` is merged down into them. Core content is intentionally duplicated across kind branches so an agent can read one branch and have the complete contract.

Layout:

- `AGENTS.md`: thin entrypoint with precedence, always-load policy, and routing pointer.
- `lab-governance/governance-init.md`: setup guide for initializing governance in a new or unverified agent workspace.
- `lab-governance/task-map.yaml`: task or session routing to the additional policy files that should be loaded. Route groups provide reusable subroutes; selected routes, not folder names, remain the explicit loading contract.
- `lab-governance/policies/enforcement-model.yaml`: bucket model for hard invariants, outcome-plus-bounds policy, and deliberately ungoverned work.
- `lab-governance/policies/runtime-surface-adapter.yaml`: runtime-surface loading, gating, capability-authority, projection, and residual-risk policy.
- `lab-governance/policies/hard-invariant-index.yaml`: tiny always-loaded guarded-domain index for context-loading the full hard-invariant register.
- `lab-governance/policies/hard-invariants.yaml`: full context-loaded Bucket A hard-invariant register.
- `lab-governance/policies/`: standing domain policies in YAML.
- `lab-governance/processes/`: meta-governance and operating processes.
- `lab-governance/skills/`: loadable skill sources that implement governance behavior in runtimes that support skills.
- `lab-governance/overrides/`: temporary exception log and its schema.
- `lab-governance/templates/`: reusable setup templates, including the local governance status template, loose local index template, and bootstrap compatibility pointer.
- `lab-governance/templates/governance-bootstrap-prompt.md`: compatibility pointer to the root-level universal canonical bootstrap prompt on literal branch `main`.
- `lab-governance/templates/experimental-channel-transition-prompt.md`: prompt for moving an already-governed workspace from the baseline policy line to the `enforcement-redesign/<endpoint>/main` policy line.
- `lab-governance/templates/kind-branch-migration-checklist.md`: version-agnostic checklist for adopting a target kind branch without hard-coding a particular canon version.
- `lab-governance/templates/local-index.yaml`: loose pointer template for `.governance/local/index.yaml`; the local directory's internal structure remains workspace-owned.
- `lab-governance/templates/local-status.yaml`: local status template for downstream `lab-governance/status.yaml`; this is metadata, not a local policy body.
- `lab-governance/status.yaml`: source-branch maintainer status for this repository. Do not copy this concrete file into downstream workspaces; generate downstream status from `lab-governance/templates/local-status.yaml`.
- `lab-governance/templates/task-brief.md`: standard brief shape for objective, definition of done, bounds, risk, budget, and stopping condition.

Kind branches add `lab-governance/branch-descriptor.yaml` and `lab-governance/kind-routes.yaml`. The policy-line trunk does not carry those files, so policy-line trunk merge-downs do not overwrite kind orientation or kind-specific routing.
