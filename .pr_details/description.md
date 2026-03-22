## Summary

- add a local `scripts/draft_release_notes.sh` workflow that drafts Keep a Changelog-style release notes from a git ref range
- fix the two reviewed correctness bugs by keeping the final `git log` record in-range and making deduplication operate on normalized subjects instead of full bullet text
- preserve commit-prefix categorization by classifying from the raw subject while still rendering normalized bullet text
- document usage and contributor workflow updates in `README.md`, `TECHNICAL.md`, `CONTRIBUTING.md`, and `CHANGELOG.md`

## Assumptions

- "Release Note Drafter" means a reusable local script, not an external integration
- default behavior should draft from the latest reachable semver tag to `HEAD`
- categorization should stay deterministic and heuristic, using commit subjects and changed paths only

## Implementation Notes

- `--from` remains exclusive and `--to` remains inclusive
- the reader loop now handles the final `git log --pretty=format` record even when it lacks a trailing newline
- categorization now reads the raw commit subject, while displayed bullet text still uses the normalized subject
- section files now store `subject<TAB>short_sha`, and render-time deduplication collapses repeated normalized subjects while preserving first-seen order and aggregating SHAs

## Sample Output

```md
## Release Notes Draft

- Generated: 2026-03-22
- Range: `v1.1.2..HEAD`
- Commits analyzed (no merges): 3

### Added
- add release note drafter script (abc1234)

### Documentation
- document release-note drafter usage (def5678, 9ab0cde)
```

## Validation

- `bash -n scripts/draft_release_notes.sh`
- `bash -n ./.copilot_yolo.sh ./.copilot_yolo_entrypoint.sh ./.copilot_yolo_config.sh ./install.sh`
- clean temporary repo repro before fix confirmed:
  - oldest commit in requested range was dropped
  - duplicate bullets were not collapsed because SHAs made every line unique
- clean temporary repo smoke tests after fix confirmed:
  - explicit `--from ... --to HEAD` includes the oldest in-range commit
  - repeated subjects collapse to one bullet with combined SHAs
  - `feat:` / `fix:` / `docs:` prefixes land in the expected sections again
  - default latest-tag-to-`HEAD` flow emits expected markdown
- wrapper `health`, `config`, and dry-run checks are blocked in this environment because `docker` is not installed on PATH

## PR Context

- this branch supersedes the earlier failing implementation on PR #18 with a corrected follow-up branch from `main`
