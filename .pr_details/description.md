## Summary

Fix two confirmed runtime bugs in the wrapper stack and add regression coverage for both.

- make ownership cleanup follow the configured `COPILOT_YOLO_WORKDIR` instead of always scanning `/workspace`
- rebuild an existing image when the embedded `@github/copilot` version is stale even if the embedded `copilot_yolo` version already matches `VERSION`
- clean up the self-update temporary download directory before the wrapper `exec`s into the new version
- document the corrected cleanup and rebuild behavior and bump `VERSION` to `1.1.4`

## Validation

Local validation in this environment used deterministic Docker/npm stubs because Docker is not installed here:

- `bash -n .copilot_yolo.sh .copilot_yolo_entrypoint.sh .copilot_yolo_config.sh install.sh`
- `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 bash ./.copilot_yolo.sh health`
- `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 bash ./.copilot_yolo.sh config`
- `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_DRY_RUN=1 bash ./.copilot_yolo.sh --help`
- installer smoke test using a temporary `COPILOT_YOLO_DIR`
- regression check that dry-run wiring includes `TARGET_WORKDIR=/custom/workspace`
- regression check that a stale embedded Copilot CLI version triggers a rebuild when npm reports a newer version

CI coverage now also includes:

- a containerized custom-workdir cleanup test that creates a root-owned file under a non-default workdir and verifies exit cleanup restores host ownership
- a stubbed rebuild-decision test that proves a stale embedded Copilot CLI version still triggers a rebuild

## Assumptions

The requested base branch `nightshift/cost-attribution-estimator` was not available locally or on `origin`, so this branch was created from `feat/build-optimize-iter3` to keep the change isolated and reviewable.
