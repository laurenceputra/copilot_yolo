# AGENTS

## Start here (required)
- Before starting any task or change, refresh this file (re-open `AGENTS.md`) so you are following the latest instructions.

## Project overview
- This repo ships a Bash wrapper (`.copilot_yolo.sh`) and Dockerfile (`.copilot_yolo.Dockerfile`) to run the GitHub Copilot CLI in a disposable container.
- Core files: `.copilot_yolo_entrypoint.sh`, `install.sh`, `VERSION`
- Module files: `.copilot_yolo_config.sh` (configuration), `.copilot_yolo_logging.sh` (logging utilities)
- Completion files: `.copilot_yolo_completion.bash`, `.copilot_yolo_completion.zsh`
- Documentation: `README.md`, `TECHNICAL.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `AGENTS.md`

## Commit policy
- Create a commit at the end of each sizable change.
- Keep commits scoped to a single logical change; do not bundle unrelated edits.
- Use clear, imperative commit messages.

## Validation
- If Docker is available, spot-check with `./.copilot_yolo.sh --help` or a fresh run.
- If Docker is unavailable, note that validation could not be run.
