# Technical Documentation

This document explains how the current `copilot_yolo` implementation behaves on
`main`, with an emphasis on startup flow, configuration, container execution, CI,
and contributor/release discipline.

## Runtime components

```text
.copilot_yolo.sh              Main orchestration wrapper
.copilot_yolo.Dockerfile      Docker image definition
.copilot_yolo_entrypoint.sh   Container entrypoint and user/cleanup setup
.copilot_yolo_config.sh       Optional config loader and sample config generator
.copilot_yolo_completion.bash Bash completion script
.copilot_yolo_completion.zsh  Zsh completion script
install.sh                    Installer and shell-profile bootstrapper
```

## Startup sequence in `.copilot_yolo.sh`

The wrapper does more work before command handling than the README-level usage
might suggest. The current sequence is:

1. Resolve `SCRIPT_DIR`
2. Source `.copilot_yolo_config.sh` when it exists and call `load_config || true`
3. Establish runtime defaults (`IMAGE`, workspace, UID/GID, repo/branch, local `VERSION`)
4. Require `docker` on `PATH` and require a running Docker daemon
5. Perform the wrapper self-update check unless `COPILOT_SKIP_UPDATE_CHECK=1`
6. Warn when Docker Buildx is missing unless version checks are skipped entirely
7. Parse wrapper-specific arguments (`--pull`, `health`, `config`, `--mount-ssh`)
8. Validate container path overrides and warn on non-default images
9. Decide whether the Docker image must be rebuilt
10. Assemble Docker mounts and environment variables
11. Handle `config`, `health`, SSH warning/mounting, and dry-run behavior
12. Build the image when needed, then `docker run ... copilot ...`

Two consequences matter for debugging and docs:

- `health`, `config`, and dry-run still happen **after** Docker preflight, so they
  do not run on a machine where `docker` is missing or the daemon is stopped.
- The optional config module is loaded before image/build decisions, so config can
  change startup defaults rather than only affecting the process inside the container.

## Configuration system

### Two-layer config model

The wrapper uses two files for configuration support:

1. **Config module**: `.copilot_yolo_config.sh`
   - shipped with current installs
   - defines `load_config()` and `generate_sample_config()`
   - optional for backward compatibility with older installs

2. **Config file**: `.copilot_yolo.conf`
   - sourced as bash if it exists
   - expected next to `.copilot_yolo.sh`
   - default installed location: `~/.copilot_yolo/.copilot_yolo.conf`

Current loading logic:

```bash
if [[ -f "${SCRIPT_DIR}/.copilot_yolo_config.sh" ]]; then
  source "${SCRIPT_DIR}/.copilot_yolo_config.sh"
  load_config || true
fi
```

Important details:

- Missing config support does **not** break the wrapper; it simply falls back to defaults
- Missing `.copilot_yolo.conf` is normal and returns a non-zero status that is ignored
- The config file is sourced as shell, so it can set exported variables directly
- `copilot_yolo config` writes a sample config next to the script that is running

### Supported configuration knobs

The sample config and runtime recognize these persistent settings:

- image/build settings: `COPILOT_BASE_IMAGE`, `COPILOT_YOLO_IMAGE`
- container paths: `COPILOT_YOLO_HOME`, `COPILOT_YOLO_WORKDIR`
- cleanup/update behavior: `COPILOT_YOLO_CLEANUP`, `COPILOT_SKIP_UPDATE_CHECK`, `COPILOT_SKIP_VERSION_CHECK`
- build toggles: `COPILOT_BUILD_NO_CACHE`, `COPILOT_BUILD_PULL`
- wrapper update source: `COPILOT_YOLO_REPO`, `COPILOT_YOLO_BRANCH`

## Update and rebuild behavior

There are two distinct freshness checks.

### Wrapper self-update

Unless `COPILOT_SKIP_UPDATE_CHECK=1`, the wrapper compares its local `VERSION` to
`https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION`.

If the versions differ, it downloads the required runtime files:

- `.copilot_yolo.sh`
- `.copilot_yolo.Dockerfile`
- `.copilot_yolo_entrypoint.sh`
- `VERSION`

It also attempts to download optional companion files without failing the update:

- `.dockerignore`
- `.copilot_yolo_config.sh`
- `.copilot_yolo_completion.bash`
- `.copilot_yolo_completion.zsh`

After copying the new files into `SCRIPT_DIR`, it re-execs the updated wrapper.

### Copilot CLI image rebuilds

The local Docker image is rebuilt when one of these is true:

- no local image exists yet
- `COPILOT_BUILD_NO_CACHE=1`
- `COPILOT_BUILD_PULL=1` or `--pull` was passed
- the embedded `copilot_yolo` version inside the image differs from local `VERSION`
- the embedded `@github/copilot` version differs from the latest npm version

If `COPILOT_SKIP_VERSION_CHECK=1`, the wrapper skips the npm lookup and reuses the
existing image unless another rebuild trigger applies. If no image exists yet,
the build still proceeds with the Dockerfile default `COPILOT_VERSION=latest`.

### Build performance optimizations

The wrapper runs image builds with `DOCKER_BUILDKIT=1`, and
`.copilot_yolo.Dockerfile` opts into modern Dockerfile syntax so it can use
BuildKit cache mounts:

- `/var/cache/apt` is cached across rebuilds
- `/var/lib/apt/lists` is cached across rebuilds
- `/root/.npm` is cached across rebuilds

The `apt` build step also temporarily disables Debian's
`/etc/apt/apt.conf.d/docker-clean` policy before installing packages, then
restores it before the layer is committed. That matters because the default
policy would delete the downloaded package archives from `/var/cache/apt`, which
would make the cache mount far less useful on repeat builds.

Because those paths are mounted as BuildKit caches during the `RUN` step, they
are not committed into the final image layer. In other words, the build can keep
warm package-manager caches without shipping those caches in the runtime image.

The build context is also intentionally allowlisted through `.dockerignore`.
Only `.copilot_yolo.Dockerfile` and `.copilot_yolo_entrypoint.sh` are included
as ordinary context inputs, which keeps docs, CI files, git metadata, and local
PR-prep artifacts out of rebuilds.

Contributor implication: if you add a new `COPY` or `ADD` source to
`.copilot_yolo.Dockerfile`, you must update `.dockerignore` in the same change
or the build will fail because that file is not part of the context.

## Command handling

### Wrapper-specific arguments

The wrapper consumes these arguments itself:

- `--pull`
- `health` / `--health`
- `config` / `--generate-config`
- `--mount-ssh`

All remaining arguments are forwarded to `copilot`.

### `login` special case

The wrapper normally prepends `--yolo` to the Copilot command. The only explicit
exception is `login`:

```bash
copilot_cmd=(copilot)
if [[ "${#pass_args[@]}" -eq 0 || "${pass_args[0]}" != "login" ]]; then
  copilot_cmd+=(--yolo)
fi
```

### Dry-run behavior

`COPILOT_DRY_RUN=1` exits before any `docker build` or `docker run`, but only after
startup has already determined whether a build would be needed and which Docker
arguments would be used.

The output includes:

- the computed `docker build` command when a rebuild is required
- the computed `docker run` command
- the final `copilot` command

### `config` and `health`

Both flows happen after Docker preflight and after build/version decision logic.
That means they are useful for inspection, but they are not "offline" commands.

- `config` sources the config module and calls `generate_sample_config`
- `health` prints Docker status, image status, latest CLI version (when available), and host-side credential path availability

## Docker execution model

### Mounts and environment

The wrapper always mounts the current working directory into the container workdir.
Depending on host state and flags, it may also add:

- `~/.copilot` → `${CONTAINER_HOME}/.copilot`
- `${XDG_CONFIG_HOME:-$HOME/.config}/gh` → `${CONTAINER_HOME}/.config/gh`
- `~/.gitconfig` → `${CONTAINER_HOME}/.gitconfig:ro`
- `GH_TOKEN` / `GITHUB_TOKEN` as pass-through environment variables
- `~/.ssh` → `${CONTAINER_HOME}/.ssh:ro` when `--mount-ssh` is requested

The wrapper also injects:

- host UID/GID and user/group names
- `TARGET_HOME`
- `COPILOT_YOLO_CLEANUP`

### User mapping and sudo

`.copilot_yolo_entrypoint.sh` starts as root, then ensures a group and user exist
for the requested UID/GID. It finally executes the target command through:

```sh
gosu "${TARGET_UID}:${TARGET_GID}" "$@"
```

So normal work runs as the mapped host user, not as root. The entrypoint also
creates `/etc/sudoers.d/90-copilot` with passwordless sudo for that mapped user.
That keeps privileged package-install workflows possible without giving up the host
UID/GID mapping for normal edits.

## Ownership restoration and cleanup

The cleanup logic lives in `.copilot_yolo_entrypoint.sh`.

Current behavior:

1. Register `trap 'check_workspace_ownership; cleanup' EXIT`
2. On exit, search `/workspace` for any file whose UID or GID does not match the target user
3. Set `workspace_changed=1` only when a mismatch is found
4. If `COPILOT_YOLO_CLEANUP` is `1` or `true`, run `chown -R "${TARGET_UID}:${TARGET_GID}" /workspace`
5. Skip the recursive `chown` entirely when there is no mismatch

The entrypoint also ensures the target home directory exists and attempts to chown
`TARGET_HOME` to the mapped UID/GID.

Practical implication: most files stay correctly owned because the command runs as
the mapped user. Cleanup mainly protects against workflows that use `sudo` or
otherwise create mismatched ownership.

## Installer behavior (`install.sh`)

The installer:

1. Detects the target profile (`$COPILOT_YOLO_PROFILE`, zsh, bash, then `.profile`)
2. Downloads required runtime files plus optional config/completion files
3. Marks `.copilot_yolo.sh` executable
4. Writes an `env` file that defines the `copilot_yolo` shell function and sources completions
5. Appends `source "${INSTALL_DIR}/env"` to the chosen profile only once
6. Prints Docker/Buildx guidance

Re-running the installer is the supported way to refresh the install directory.

## CI coverage

GitHub Actions currently runs these checks in `.github/workflows/ci.yml`:

1. **ShellCheck Linting** for the shell scripts
2. **Metrics coverage analysis** for the shell instrumentation manifest
3. **Install Script Test** on Ubuntu and macOS
4. **Health Check Test**
5. **Config Generation Test**
6. **Dry Run Test**
7. **VERSION format validation**
8. **VERSION guard for runtime files**

### Metrics coverage analyzer

The metrics taxonomy for static validation lives in
`metrics/coverage_manifest.json`. The analyzer itself lives in
`scripts/analyze_metrics_coverage.js` and scans these runtime surfaces:

- `.copilot_yolo.sh`
- `install.sh`
- `.copilot_yolo_config.sh`
- `.copilot_yolo_entrypoint.sh`

Each required flow declares the canonical event IDs and the file where each
`emit_metric "event.id"` call must appear. The analyzer reports:

- **covered** when an expected event appears exactly once in the expected file
- **missing** when no matching call exists
- **ambiguous** when duplicate calls exist or the event appears in the wrong file
- **untracked** when the source contains event IDs not declared in the manifest

That makes taxonomy drift explicit in CI and keeps the instrumentation rules
reviewable outside the analyzer code.

For local debugging, `COPILOT_YOLO_METRICS_TRACE=1` prints the event IDs to
stderr in both the wrapper and the container entrypoint.

### Runtime-file VERSION guard

CI fails the PR when any of these files change without a matching `VERSION` update:

- `.copilot_yolo.sh`
- `.copilot_yolo.Dockerfile`
- `.copilot_yolo_entrypoint.sh`
- `.copilot_yolo_config.sh`
- `.copilot_yolo_completion.bash`
- `.copilot_yolo_completion.zsh`
- `install.sh`
- `.dockerignore`

`AGENTS.md` documents the same list and should stay aligned with the workflow guard.

## Development workflow

Recommended contributor flow:

1. Branch from `main`
2. Make runtime/docs changes together
3. Bump `VERSION` if a distributed runtime file changed
4. Update `CHANGELOG.md` for notable changes
5. Write `.pr_details/description.md` and use it for the GitHub PR body
6. Run the relevant lightweight checks locally
7. Open the PR against `main`

Suggested local checks:

```bash
bash -n .copilot_yolo.sh .copilot_yolo_config.sh .copilot_yolo_entrypoint.sh install.sh
node scripts/analyze_metrics_coverage.js --manifest metrics/coverage_manifest.json --format text --fail-on-issues
COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh health
COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh config
COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_DRY_RUN=1 ./.copilot_yolo.sh --help
```

When changing `.dockerignore` or `.copilot_yolo.Dockerfile`, it is also worth
running a cold Docker build followed by a warm repeat build and comparing the
reported `transferring context` size plus cache hits:

```bash
DOCKER_BUILDKIT=1 docker build --no-cache -f .copilot_yolo.Dockerfile -t copilot-yolo:bench .
DOCKER_BUILDKIT=1 docker build -f .copilot_yolo.Dockerfile -t copilot-yolo:bench .
```

If Docker-dependent checks are unavailable, record that limitation in the PR body.

## Release workflow

The current repository state on `main` does **not** include
`scripts/draft_release_notes.sh`. `.pr_details/` is gitignored, so maintainers
should treat it as local PR-prep material rather than repository state. Until
that helper exists again, draft release notes from:

- merged GitHub PR descriptions
- `CHANGELOG.md`
- the tagged diff for the release

A practical maintainer release sequence is:

1. Merge PRs into `main`
2. Verify all runtime-file changes included a `VERSION` bump
3. Promote or reorganize the relevant `CHANGELOG.md` entries for the release
4. Tag the release from `main`
5. Push the tag so downstream installs can pick up the new `VERSION`

## Debugging notes

- Missing Docker or a stopped daemon fails the wrapper before command-specific logic
- Missing Buildx only emits a warning; the wrapper can still continue
- A missing config module or missing `.copilot_yolo.conf` is non-fatal
- `COPILOT_YOLO_HOME` and `COPILOT_YOLO_WORKDIR` must be absolute container paths
- A non-default `COPILOT_YOLO_IMAGE` triggers a trust warning
