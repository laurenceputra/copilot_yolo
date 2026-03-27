# Contributing to copilot_yolo

Thanks for contributing to `copilot_yolo`.

## Development setup

```bash
git clone https://github.com/laurenceputra/copilot_yolo.git
cd copilot_yolo
chmod +x .copilot_yolo.sh
```

The top-level runtime and docs files you will usually touch are:

- `.copilot_yolo.sh`
- `.copilot_yolo.Dockerfile`
- `.copilot_yolo_entrypoint.sh`
- `.copilot_yolo_config.sh`
- `.copilot_yolo_completion.bash`
- `.copilot_yolo_completion.zsh`
- `install.sh`
- `README.md`
- `TECHNICAL.md`
- `CHANGELOG.md`

## Branch strategy

Create feature branches from `main`; do not work directly on `main`.

```bash
git switch main
git switch -c docs/example-change
```

Guidelines:

- Keep branch names descriptive (`docs/...`, `fix/...`, `feature/...`)
- Open PRs against `main`
- Expect CI to run on PRs to `main` and on pushes to `main`

## Documentation expectations

Keep the docs aligned with the shipped behavior in the same PR.

Update these files when applicable:

- `README.md` for user-facing behavior such as commands, mounts, auth, or configuration
- `TECHNICAL.md` for implementation details, startup flow, CI behavior, or release process
- `CHANGELOG.md` for notable changes, including documentation-only updates when they matter to users or contributors
- `CONTRIBUTING.md` when the contributor workflow or validation expectations change

If you change runtime behavior, make the docs update part of the same branch rather
than a follow-up cleanup.

## VERSION bump rule for runtime files

Changes to distributed runtime files must include a `VERSION` bump in the same PR.
CI enforces this rule in `.github/workflows/ci.yml`.

Guarded runtime files are:

- `.copilot_yolo.sh`
- `.copilot_yolo.Dockerfile`
- `.copilot_yolo_entrypoint.sh`
- `.copilot_yolo_config.sh`
- `.copilot_yolo_completion.bash`
- `.copilot_yolo_completion.zsh`
- `install.sh`
- `.dockerignore`

Pure documentation changes do not require a `VERSION` bump.

## Validation

Run the existing lightweight checks that match your change.

Always safe to run:

```bash
bash -n .copilot_yolo.sh .copilot_yolo_config.sh .copilot_yolo_entrypoint.sh install.sh
node scripts/analyze_metrics_coverage.js --manifest metrics/coverage_manifest.json --format text --fail-on-issues
```

When Docker is available locally, also use the same entry points covered by CI:

```bash
COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh health
COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_SKIP_VERSION_CHECK=1 ./.copilot_yolo.sh config
COPILOT_SKIP_UPDATE_CHECK=1 COPILOT_DRY_RUN=1 ./.copilot_yolo.sh --help
```

If Docker-dependent checks are not available in your environment, note that in the
PR description.

## PR description workflow

Always write the PR summary in `.pr_details/description.md` before opening the PR.
That file should capture:

- what changed and why
- any assumptions or trade-offs
- validation performed
- environment limitations encountered while testing

`.pr_details/` is gitignored, so treat `description.md` as local PR-prep
material and as the source for the GitHub PR body rather than a file that will
ship on `main`.

You can use it directly when opening the PR:

```bash
gh pr create --body-file .pr_details/description.md
```

`main` does not currently include `scripts/draft_release_notes.sh`, so keep the
GitHub PR body and `CHANGELOG.md` accurate enough to serve as release-note
source material until that helper exists again.

## Pull request checklist

Before opening a PR:

1. Branch from `main`
2. Make the code and documentation changes together
3. Update `CHANGELOG.md` when the change is notable
4. Bump `VERSION` if you changed any distributed runtime file
5. Write `.pr_details/description.md`
6. Run the relevant validations
7. Push your branch and open the PR against `main`

## Release workflow

For maintainers, the current release flow is:

1. Merge reviewed PRs into `main`
2. Ensure runtime-file changes landed with a matching `VERSION` bump
3. Promote `CHANGELOG.md` notes into the next tagged release entry
4. Tag and publish the release from `main`

Because the repo does not currently ship `scripts/draft_release_notes.sh` on
`main`, draft release notes from the merged GitHub PR descriptions and
`CHANGELOG.md`.

## Questions

Open an issue if you need clarification on the workflow or architecture.
