## Problem statement

The docs-backfill task required filling high-impact documentation gaps without changing runtime behavior. Previous iterations were close, but review found one material accuracy issue in `TECHNICAL.md` rebuild logic wording and stale internals snippets.

## Scope assumptions

- Keep this as a docs-only update (no runtime script edits).
- Prioritize accuracy for command behavior, configuration semantics, and CI/process alignment.
- Avoid full rewrite; focus on high-value missing/incorrect sections.

## What changed

- `README.md`
  - Added a command behavior reference that documents wrapper behavior vs pass-through behavior.
  - Clarified `login` special handling (no automatic `--yolo`).
  - Explicitly documented wrapper-only flags/commands (`--pull`, `--mount-ssh`, `health`, `config`).
  - Expanded configuration docs with bash-sourced config format, precedence implications, and practical setup examples.
  - Updated update/rebuild section wording to reflect actual implementation behavior.

- `TECHNICAL.md`
  - Corrected rebuild trigger documentation to match current control flow (explicit rebuild flags, image-missing case, local-version mismatch, npm fallback path).
  - Updated argument parsing snippet to include `--mount-ssh`.
  - Updated CI section to reflect current workflow checks (removed stale Docker build test claim, added dry-run test, VERSION guard wording).
  - Refreshed config module snippet to match current single-file loading behavior.

- `CHANGELOG.md`
  - Added an `[Unreleased]` documentation entry summarizing this docs backfill.

## Validation notes

- Ran `git diff --check` to validate patch formatting.
- Ran focused consistency checks with `rg` across docs for:
  - rebuild trigger wording
  - CI job list parity with `.github/workflows/ci.yml`
  - command/config semantics (`login`, `--mount-ssh`, config sourcing)
- Confirmed this PR only changes documentation and `.pr_details/description.md`.
- Confirmed no distributed runtime files were modified, so no `VERSION` bump is required.

## Rollout / impact

- User-facing behavior is unchanged.
- Documentation now more accurately reflects current wrapper internals and CI safeguards.
- This reduces confusion for contributors and should eliminate the previously flagged TECHNICAL mismatch.
