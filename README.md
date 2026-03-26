# copilot_yolo

Run the GitHub Copilot CLI in a disposable Docker container with your current
repository mounted into the container. The wrapper builds a local image and runs
Copilot in yolo mode by default, while also making `gh`, `rg`, and the OpenSSH
client available for PR-oriented workflows.

Only the working repository and the documented credential mounts are exposed by
default. Other host paths are not available unless the wrapper explicitly mounts
them, such as `~/.ssh` when you opt into `--mount-ssh`.

## ✨ What's New in v1.1.0

Version 1.1.0 added the current configuration, health-check, completion, and CI
foundation while keeping existing workflows compatible.

- 🏥 **Health check**: `copilot_yolo health`
- ⚙️ **Configuration file support**: `copilot_yolo config`
- 🔧 **Shell completions**: bash and zsh completions are installed by default
- ✅ **CI checks**: ShellCheck plus install/config/dry-run coverage
- 🎯 **Better diagnostics**: more actionable Docker and environment guidance

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Requirements

- Docker (Desktop or Engine)
- Bash (macOS/Linux; Windows via WSL recommended)
- Docker Buildx (recommended for reliable builds and faster repeat builds): https://docs.docker.com/build/buildx/

## Faster Docker rebuilds

The local image build keeps its Docker build context intentionally tiny. Only
`.copilot_yolo.Dockerfile` and `.copilot_yolo_entrypoint.sh` are included as
ordinary context inputs, so rebuilds do not resend docs, CI files, git
metadata, or local PR-prep artifacts.

The Dockerfile also uses BuildKit cache mounts for `apt` and `npm`. During the
`apt` step it temporarily disables Debian's default `docker-clean` policy so the
cache mounts can retain downloaded package data between rebuilds, then restores
that policy before the layer is committed to preserve the final runtime image
behavior.

The wrapper already rebuilds with `DOCKER_BUILDKIT=1`, so warm rebuilds can
reuse package-manager caches when Docker BuildKit is available.

If you add a new `COPY` or `ADD` source to `.copilot_yolo.Dockerfile`, update
`.dockerignore` in the same change or the build will not see that file.

Validate the cache behavior locally with a cold build followed by an immediate
repeat build:

```bash
DOCKER_BUILDKIT=1 docker build --no-cache \
  -f .copilot_yolo.Dockerfile \
  -t copilot-yolo:bench \
  --build-arg COPILOT_YOLO_VERSION="$(cat VERSION)" \
  .

DOCKER_BUILDKIT=1 docker build \
  -f .copilot_yolo.Dockerfile \
  -t copilot-yolo:bench \
  --build-arg COPILOT_YOLO_VERSION="$(cat VERSION)" \
  .
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/copilot_yolo/main/install.sh | bash
```

By default the installer writes into `~/.copilot_yolo` and appends one `source`
line to the shell profile it detects. You can override both locations:

```bash
COPILOT_YOLO_DIR="$HOME/.copilot_yolo" \
COPILOT_YOLO_PROFILE="$HOME/.zshrc" \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/laurenceputra/copilot_yolo/main/install.sh)"
```

### Installation details

The installer is safe to re-run. On each run it:

1. Downloads the distributed runtime files into `COPILOT_YOLO_DIR`
2. Creates `COPILOT_YOLO_DIR/env`, which defines the `copilot_yolo` shell function
3. Loads bash or zsh completions from the install directory when available
4. Appends `source ".../env"` to the detected profile only if it is not already present
5. Prints Docker and Buildx guidance after installation

Profile detection follows this order:

- `$COPILOT_YOLO_PROFILE` if you set it explicitly
- `$ZDOTDIR/.zshrc` when `ZDOTDIR` is set
- `~/.zshrc` for zsh shells
- `~/.bashrc` for bash shells
- `~/.profile` as a fallback

## Quick start

```bash
copilot_yolo
```

Arguments are forwarded to `copilot`. Most commands run as `copilot --yolo ...`.
The exception is `copilot_yolo login`, which forwards to `copilot login` without
adding `--yolo`.

Pass-through arguments are supported as usual:

```bash
copilot_yolo --help
copilot_yolo review README.md
```

## Dry-run mode

Preview the exact Docker commands without building or running the container after
the wrapper finishes its normal Docker preflight checks:

```bash
COPILOT_DRY_RUN=1 copilot_yolo --help
```

Dry-run mode prints:

- the `docker build` command when the wrapper decides a rebuild is needed
- the full `docker run` command, including mounts and environment variables
- the final `copilot` command that would run inside the container

This is the quickest way to confirm mounts, arguments, and image settings before
changing configuration.

## Health check

```bash
copilot_yolo health
```

When Docker is installed and the daemon is running, the health check reports:

- Docker and Docker daemon status
- Docker Buildx availability
- the local `copilot_yolo` version
- whether the Docker image already exists
- host-side credential and SSH paths that the wrapper can mount

> `copilot_yolo` currently performs Docker preflight checks before command
> handling. If Docker is missing or the daemon is stopped, `health`, `config`,
> and dry-run invocations fail early with the same setup guidance as a normal
> run.

## Login and authentication

The first run prompts you to sign in if needed. You can also log in explicitly:

```bash
copilot_yolo login
copilot_yolo login --help
```

Host credentials are reused when present:

- `~/.copilot` is mounted read-write so Copilot CLI login state can be reused
- `~/.config/gh` (or `$XDG_CONFIG_HOME/gh`) is mounted read-write so `gh` keeps working
- `~/.gitconfig` is mounted read-only
- `GH_TOKEN` and `GITHUB_TOKEN` are passed into the container if they are set on the host

### What gets shared with the container

| Host resource | Container path / form | Mode | Purpose |
| --- | --- | --- | --- |
| Current directory (`$(pwd)`) | `/workspace` by default | Read-write | Working repository files |
| `~/.copilot` | `${COPILOT_YOLO_HOME:-/home/copilot}/.copilot` | Read-write | Copilot CLI configuration and credentials |
| `~/.config/gh` or `$XDG_CONFIG_HOME/gh` | `${COPILOT_YOLO_HOME:-/home/copilot}/.config/gh` | Read-write | GitHub CLI authentication |
| `~/.gitconfig` | `${COPILOT_YOLO_HOME:-/home/copilot}/.gitconfig` | Read-only | Git configuration |
| `GH_TOKEN`, `GITHUB_TOKEN` | Environment variables | Pass-through | Token-based GitHub authentication |
| `~/.ssh` (optional) | `${COPILOT_YOLO_HOME:-/home/copilot}/.ssh` | Read-only | SSH keys for Git operations when `--mount-ssh` is used |

SSH keys are **not** mounted by default. Opt in only when you need Git-over-SSH:

```bash
copilot_yolo --mount-ssh
```

The wrapper prints a warning before mounting `~/.ssh`. Because the mount is
read-only, it is best suited for fetch/push workflows that already rely on keys
present on the host. Use branch protection on important branches if agents are
allowed to push.

## Shell completions

Shell completions for bash and zsh are installed with the wrapper. To load them
manually in the current shell:

```bash
# Bash
source ~/.copilot_yolo/.copilot_yolo_completion.bash

# Zsh
source ~/.copilot_yolo/.copilot_yolo_completion.zsh
```

## Configuration

Generate a sample configuration file (after the same Docker preflight the
wrapper uses for every other command):

```bash
copilot_yolo config
```

The configuration file lives next to the installed script:

- default install: `~/.copilot_yolo/.copilot_yolo.conf`
- custom install: `$COPILOT_YOLO_DIR/.copilot_yolo.conf`
- running directly from a checkout: `./.copilot_yolo.conf`

The file is sourced as bash near the start of `.copilot_yolo.sh`, before image
selection, build arguments, and Docker mounts are finalized. That makes it a
useful place to set persistent defaults rather than exporting the same variables
in every shell session.

Typical settings include:

- Docker image selection (`COPILOT_YOLO_IMAGE`, `COPILOT_BASE_IMAGE`)
- container paths (`COPILOT_YOLO_HOME`, `COPILOT_YOLO_WORKDIR`)
- update/build behavior (`COPILOT_SKIP_UPDATE_CHECK`, `COPILOT_SKIP_VERSION_CHECK`, `COPILOT_BUILD_NO_CACHE`, `COPILOT_BUILD_PULL`)
- cleanup behavior (`COPILOT_YOLO_CLEANUP`)
- wrapper update source (`COPILOT_YOLO_REPO`, `COPILOT_YOLO_BRANCH`)

### Supported environment variables

- `COPILOT_BASE_IMAGE` (default: `node:20-slim`)
- `COPILOT_YOLO_IMAGE` (default: `copilot-cli-yolo:local`; only use images you trust)
- `COPILOT_YOLO_HOME` (default: `/home/copilot`; must be an absolute container path)
- `COPILOT_YOLO_WORKDIR` (default: `/workspace`; must be an absolute container path and is also the path cleanup scans on exit)
- `COPILOT_YOLO_CLEANUP` (default: `1`)
- `COPILOT_YOLO_REPO` (default: `laurenceputra/copilot_yolo`)
- `COPILOT_YOLO_BRANCH` (default: `main`)
- `COPILOT_SKIP_UPDATE_CHECK=1` to skip wrapper self-update checks
- `COPILOT_SKIP_VERSION_CHECK=1` to skip npm version checks for `@github/copilot`
- `COPILOT_BUILD_NO_CACHE=1` to force a no-cache Docker rebuild
- `COPILOT_BUILD_PULL=1` to pull the base image during build
- `COPILOT_DRY_RUN=1` to print the computed Docker commands without executing them
- `--pull` to request a rebuild with `docker build --pull`
- `--mount-ssh` to mount `~/.ssh` read-only
- `health` / `--health` to print the health report
- `config` / `--generate-config` to write a sample config file

### File ownership and cleanup

The entrypoint maps your host UID/GID into the container and runs Copilot as that
user via `gosu`. It also enables passwordless `sudo` inside the container.

Most normal edits already land with the correct ownership. Cleanup matters when a
command inside the container creates files with the wrong owner or group (for
example after using `sudo`). On exit, the entrypoint:

- scans the configured container workdir (`COPILOT_YOLO_WORKDIR`, default `/workspace`) for files whose UID or GID no longer matches your host user
- runs `chown -R` only when it detects a mismatch
- skips the ownership reset entirely when `COPILOT_YOLO_CLEANUP=0`

Disable cleanup only if you understand the trade-off and are prepared to fix file
ownership manually on the host.

## Automatic updates

The wrapper has two separate update checks:

1. **Wrapper self-update** checks the remote `VERSION` file from
   `COPILOT_YOLO_REPO` / `COPILOT_YOLO_BRANCH`. If the wrapper version changed,
   it downloads the latest runtime files into the install directory and re-execs.
2. **Copilot CLI image update** checks npm for the latest `@github/copilot`
   version and rebuilds the Docker image when the local image is missing, when the
   embedded `copilot_yolo` version no longer matches the local `VERSION`, or when
   the embedded Copilot CLI version is behind npm.

Skip the wrapper update check:

```bash
COPILOT_SKIP_UPDATE_CHECK=1 copilot_yolo
```

Skip the Copilot CLI npm lookup:

```bash
COPILOT_SKIP_VERSION_CHECK=1 copilot_yolo
```

When a local image already exists, the wrapper reuses it only when both embedded
versions are current. If no image exists yet, the wrapper still builds one using
the Dockerfile default Copilot CLI version (`latest`).

The wrapper runs rebuilds with `DOCKER_BUILDKIT=1`, which activates the
Dockerfile cache mounts used for `apt` and `npm`.

Force a rebuild:

```bash
COPILOT_BUILD_NO_CACHE=1 copilot_yolo
# or
copilot_yolo --pull
```

## Update or reinstall the wrapper

Re-run the installer to refresh the files inside `COPILOT_YOLO_DIR`:

```bash
curl -fsSL https://raw.githubusercontent.com/laurenceputra/copilot_yolo/main/install.sh | bash
```

If you installed from a fork or a non-default branch, pass those again so future
self-updates keep using the same source:

```bash
COPILOT_YOLO_REPO="yourname/copilot_yolo" \
COPILOT_YOLO_BRANCH="main" \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/yourname/copilot_yolo/main/install.sh)"
```

## Troubleshooting

- **Docker missing or daemon stopped**: the wrapper exits before handling any
  command-specific flow. Install Docker, start the daemon, then retry.
- **Buildx warning**: the wrapper can still run without Buildx, but builds may be
  slower or less reliable, and warm-build cache reuse may be reduced. Install
  Docker Buildx for the best results.
- **Config changes do not seem to apply**: confirm you edited the config file next
  to the installed script (`~/.copilot_yolo/.copilot_yolo.conf` by default).
- **Authentication inside the container is missing**: run `copilot_yolo health`
  and confirm that `~/.copilot`, gh config, tokens, or `~/.ssh` are available.
- **Files ended up owned by root**: keep `COPILOT_YOLO_CLEANUP=1` enabled, then
  rerun the wrapper so the exit hook can restore ownership.
- **Custom home/workdir paths fail**: `COPILOT_YOLO_HOME` and
  `COPILOT_YOLO_WORKDIR` must be absolute container paths such as
  `/home/copilot` and `/workspace`.

For implementation details and debugging notes, see [TECHNICAL.md](TECHNICAL.md).

## Security note

The container reuses host-side credentials and exposes passwordless `sudo` to the
mapped user inside the container. That keeps workflows flexible, but it also means
changes made in `/workspace` are real host-file changes, not disposable copies.

Prefer the default mounts unless you specifically need more access, and treat
`--mount-ssh` as an opt-in power feature.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the current
branching, validation, and PR description workflow, and [TECHNICAL.md](TECHNICAL.md)
for implementation details.

## License

MIT License - see [LICENSE](LICENSE) for details.
