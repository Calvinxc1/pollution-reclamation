# Governance Bootstrap Prompt Pointer

The canonical bootstrap/update prompt lives on literal branch `main`:

```text
gitea.infra.newedenhomestead.net:ai-projects/ai-governance.git
branch: main
path: governance-bootstrap-prompt.md
```

Use the root-level universal prompt for first-time governance initialization, governed-agent verification, and governed-agent updates.

This endpoint-local file is a compatibility pointer only. Do not treat this branch's policy line as selected merely because this pointer was read from a `baseline/<endpoint>/main` or `enforcement-redesign/<endpoint>/main` branch.

The universal prompt requires an explicit target policy line before the agent mutates local governance:

```text
baseline
enforcement-redesign
```

After the target policy line and agent kind are confirmed, select the current mapped `/main` endpoint branch for that policy line and kind, then seed or update the downstream workspace from that selected branch's `lab-governance/` tree.
