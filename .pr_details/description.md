## Summary

Add a local `scripts/estimate_oncall_load.sh` utility that estimates likely
oncall/operational load from a git diff using deterministic heuristics instead
of adding a new runtime subcommand.

## Scope and assumptions

- Keep the feature as an advisory developer utility under `scripts/`
- Score load from repo-aware heuristics rather than incident history
- Prefer explainable output over opaque precision
- Avoid runtime-wrapper changes so no VERSION bump is needed

## Heuristic design

- Higher weights for distributed runtime files
- Medium weights for core shell and CI workflow changes
- Lower weights for auxiliary scripts and docs
- Additional points for churn, breadth, binary diffs, and rename-only moves
- Docs-only changes are capped in the low band

## Validation

- `bash -n scripts/estimate_oncall_load.sh`
- estimator smoke tests against temporary git repos
- existing CI-equivalent checks in `.github/workflows/ci.yml`

## Known limitations

- The score is advisory and deterministic, not predictive
- Binary impact uses fixed penalties
- Repo-specific path weighting must stay aligned with CI/runtime file policies
