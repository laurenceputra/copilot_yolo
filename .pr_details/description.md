## Summary
- add static metrics emit points across the wrapper, installer, config module, and entrypoint without changing default runtime output
- add a checked-in manifest plus a Node-based coverage analyzer and enforce it in CI
- document analyzer usage, trace debugging, and the new validation step, and bump `VERSION` to `1.1.4`

## Scope and assumptions
- Requested base branch `nightshift/event-taxonomy-normalizer` was not available locally or on `origin`, so this branch was created from `feat/build-optimize-iter3` and should be reviewed against that base.
- The repo did not already contain a reusable metrics taxonomy, so `metrics/coverage_manifest.json` now serves as the reviewable source of truth.

## Validation
- ✅ `bash -n .copilot_yolo.sh .copilot_yolo_config.sh .copilot_yolo_entrypoint.sh install.sh`
- ✅ `sh -n .copilot_yolo_entrypoint.sh`
- ✅ `node scripts/analyze_metrics_coverage.js --manifest metrics/coverage_manifest.json --format text --fail-on-issues`
- ⚠️ `shellcheck` is not installed in this environment
- ⚠️ `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh health` → Docker is not installed or running here
- ⚠️ `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh config` → Docker is not installed or running here
- ⚠️ `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_DRY_RUN=1 ./.copilot_yolo.sh --help` → Docker is not installed or running here
