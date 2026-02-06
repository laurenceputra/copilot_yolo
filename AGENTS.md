# Contributor Guardrails

## Versioning Policy

Any change to distributed runtime files must include a `VERSION` bump in the same PR.

Distributed runtime files:
- `.copilot_yolo.sh`
- `.copilot_yolo.Dockerfile`
- `.copilot_yolo_entrypoint.sh`
- `.copilot_yolo_config.sh`
- `.copilot_yolo_completion.bash`
- `.copilot_yolo_completion.zsh`
- `install.sh`
- `.dockerignore`

Keep this list aligned with the CI process guard in `.github/workflows/ci.yml`.

## PR Details Policy

Always write the PR change description in `.pr_details/description.md`.
