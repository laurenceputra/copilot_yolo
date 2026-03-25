## Summary
- tighten `.dockerignore` to allowlist only the Dockerfile and entrypoint build inputs
- enable BuildKit cache mounts for `apt` and `npm` in `.copilot_yolo.Dockerfile`
- fix the `apt` cache setup by temporarily disabling Debian's `docker-clean` policy during the build step instead of deleting the cache-mounted apt metadata
- document the lean build context and cache-validation workflow, and bump `VERSION` to `1.1.3`

## Assumptions and scope
- Interpreted "Optimize build configuration for faster builds" as improving local Docker image rebuild time without changing wrapper behavior or the CI workflow.
- Kept the work scoped to low-risk build inputs: Docker context size, Dockerfile layer/cache reuse, release notes, and contributor documentation.

## Build context impact
- Before: 14 files / 50,342 bytes
- After: 2 files / 4,305 bytes
- Reduction: 46,037 bytes (-91.4%)

## Build timing and cache validation
- Docker is not installed or not on `PATH` in this environment, so I could not run cold/warm `docker build` benchmarks here.
- The Dockerfile now opts into Dockerfile syntax `1.7`, uses BuildKit cache mounts for `/var/cache/apt`, `/var/lib/apt/lists`, and `/root/.npm`, and temporarily disables Debian's `/etc/apt/apt.conf.d/docker-clean` policy during the `apt` build step so those caches can actually persist across repeat builds without changing the final runtime image behavior.
- `README.md` and `TECHNICAL.md` include the exact cold/warm `docker build` commands contributors can run locally once Docker is available.

## Validation
- ✅ `bash -n .copilot_yolo.sh .copilot_yolo_config.sh .copilot_yolo_entrypoint.sh install.sh`
- ⚠️ `shellcheck` is not installed in this environment
- ⚠️ `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh health` → `Error: docker is not installed or not on PATH.`
- ⚠️ `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh config` → `Error: docker is not installed or not on PATH.`
- ⚠️ `COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_DRY_RUN=1 ./.copilot_yolo.sh --help` → `Error: docker is not installed or not on PATH.`
