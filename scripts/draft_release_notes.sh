#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Draft release notes from git history.

Usage:
  scripts/draft_release_notes.sh [--from <ref>] [--to <ref>] [--output <path>]

Options:
  --from <ref>     Starting ref (exclusive). Defaults to latest reachable semver tag.
  --to <ref>       Ending ref (inclusive). Defaults to HEAD.
  --output <path>  Write output markdown to file instead of stdout.
  -h, --help       Show this help text.

Examples:
  # Default range: latest semver tag -> HEAD
  scripts/draft_release_notes.sh

  # Release candidate notes from a specific tag
  scripts/draft_release_notes.sh --from v1.1.2 --to HEAD

  # Hotfix notes to a file
  scripts/draft_release_notes.sh --from v1.1.2 --to hotfix/urgent-fix --output /tmp/release-notes.md
EOF
}

error() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

normalize_subject() {
  local subject cleaned
  subject="$(trim "$1")"
  cleaned="$(printf '%s' "$subject" | sed -E 's/^[a-zA-Z][a-zA-Z0-9_-]*(\([^)]+\))?!?:[[:space:]]*//')"
  trim "${cleaned}"
}

is_semver_tag() {
  [[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]
}

is_doc_path() {
  case "$1" in
    README.md|CHANGELOG.md|CONTRIBUTING.md|TECHNICAL.md|docs/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_ci_path() {
  case "$1" in
    .github/workflows/*|.github/actions/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

find_latest_semver_tag() {
  local to_ref="$1" tag
  while IFS= read -r tag; do
    if is_semver_tag "$tag"; then
      printf '%s\n' "$tag"
      return 0
    fi
  done < <(git tag --merged "$to_ref" --sort=-v:refname)
  return 1
}

classify_by_paths() {
  local paths="$1"
  local path has_doc=0 has_non_doc=0 has_ci=0 has_non_ci=0

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if is_doc_path "$path"; then
      has_doc=1
    else
      has_non_doc=1
    fi
    if is_ci_path "$path"; then
      has_ci=1
    else
      has_non_ci=1
    fi
  done <<< "$paths"

  if [[ "$has_ci" -eq 1 && "$has_non_ci" -eq 0 ]]; then
    printf 'CI\n'
    return 0
  fi
  if [[ "$has_doc" -eq 1 && "$has_non_doc" -eq 0 ]]; then
    printf 'Documentation\n'
    return 0
  fi
  printf 'Changed\n'
}

categorize_commit() {
  local subject="$1" paths="$2" lc_subject path_category
  lc_subject="$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]')"

  if [[ "$lc_subject" =~ ^(feat|feature|add|adds|added|introduce|new)(\(|:|[[:space:]]) ]]; then
    printf 'Added\n'
    return 0
  fi
  if [[ "$lc_subject" =~ ^(fix|fixed|bugfix|hotfix|patch|resolve|resolved|repair)(\(|:|[[:space:]]) ]]; then
    printf 'Fixed\n'
    return 0
  fi
  if [[ "$lc_subject" =~ ^(docs|doc|documentation|readme|changelog|contributing|technical)(\(|:|[[:space:]]) ]]; then
    printf 'Documentation\n'
    return 0
  fi
  if [[ "$lc_subject" =~ ^(ci|build|workflow|actions)(\(|:|[[:space:]]) ]]; then
    printf 'CI\n'
    return 0
  fi

  path_category="$(classify_by_paths "$paths")"
  printf '%s\n' "$path_category"
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error "this script must run inside a git repository."
fi

from_ref=""
to_ref="HEAD"
output_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      [[ $# -ge 2 ]] || error "--from requires a value."
      from_ref="$2"
      shift 2
      ;;
    --to)
      [[ $# -ge 2 ]] || error "--to requires a value."
      to_ref="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || error "--output requires a value."
      output_path="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "unknown argument: $1"
      ;;
  esac
done

git rev-parse --verify --quiet "${to_ref}^{commit}" >/dev/null || error "invalid --to ref: ${to_ref}"

auto_from=0
if [[ -z "$from_ref" ]]; then
  if from_ref="$(find_latest_semver_tag "$to_ref" 2>/dev/null)"; then
    auto_from=1
  else
    from_ref=""
  fi
fi

if [[ -n "$from_ref" ]]; then
  git rev-parse --verify --quiet "${from_ref}^{commit}" >/dev/null || error "invalid --from ref: ${from_ref}"
fi

range_spec="$to_ref"
from_display="start-of-history"
if [[ -n "$from_ref" ]]; then
  range_spec="${from_ref}..${to_ref}"
  from_display="$from_ref"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

added_file="${tmp_dir}/Added"
changed_file="${tmp_dir}/Changed"
fixed_file="${tmp_dir}/Fixed"
docs_file="${tmp_dir}/Documentation"
ci_file="${tmp_dir}/CI"
touch "$added_file" "$changed_file" "$fixed_file" "$docs_file" "$ci_file"

commit_count=0
while IFS=$'\t' read -r sha subject || [[ -n "${sha:-}" ]]; do
  [[ -z "$sha" ]] && continue
  commit_count=$((commit_count + 1))

  raw_subject="$subject"
  subject="$(normalize_subject "$raw_subject")"
  lc_subject="$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$subject" || "$lc_subject" == "initial plan" ]]; then
    continue
  fi

  changed_paths="$(git show --name-only --pretty=format: "$sha" | sed '/^$/d')"
  category="$(categorize_commit "$raw_subject" "$changed_paths")"
  short_sha="$(git rev-parse --short "$sha")"

  case "$category" in
    Added)
      printf '%s\t%s\n' "$subject" "$short_sha" >> "$added_file"
      ;;
    Fixed)
      printf '%s\t%s\n' "$subject" "$short_sha" >> "$fixed_file"
      ;;
    Documentation)
      printf '%s\t%s\n' "$subject" "$short_sha" >> "$docs_file"
      ;;
    CI)
      printf '%s\t%s\n' "$subject" "$short_sha" >> "$ci_file"
      ;;
    *)
      printf '%s\t%s\n' "$subject" "$short_sha" >> "$changed_file"
      ;;
  esac
done < <(git log --no-merges --pretty=format:'%H%x09%s' "$range_spec")

render_section() {
  local title="$1" section_file="$2"
  if [[ -s "$section_file" ]]; then
    printf '### %s\n' "$title"
    awk -F '\t' '
      NF >= 2 {
        key = tolower($1)

        if (!(key in seen)) {
          seen[key] = 1
          order[++count] = key
          subject[key] = $1
          shas[key] = $2
          next
        }

        sha_count = split(shas[key], existing_shas, /, /)
        for (i = 1; i <= sha_count; i++) {
          if (existing_shas[i] == $2) {
            next
          }
        }

        shas[key] = shas[key] ", " $2
      }

      END {
        for (i = 1; i <= count; i++) {
          key = order[i]
          printf "- %s (%s)\n", subject[key], shas[key]
        }
      }
    ' "$section_file"
    printf '\n'
  fi
}

notes="$(
  {
    printf '## Release Notes Draft\n\n'
    printf -- '- Generated: %s\n' "$(date -u +'%Y-%m-%d')"
    printf -- '- Range: `%s..%s`\n' "$from_display" "$to_ref"
    printf -- '- Commits analyzed (no merges): %s\n' "$commit_count"
    if [[ "$auto_from" -eq 1 ]]; then
      printf -- '- Default start ref auto-detected from latest semver tag\n'
    fi
    printf '\n'
    render_section "Added" "$added_file"
    render_section "Changed" "$changed_file"
    render_section "Fixed" "$fixed_file"
    render_section "Documentation" "$docs_file"
    render_section "CI" "$ci_file"
  } | sed '/^[[:space:]]*$/N;/^\n$/D'
)"

if ! printf '%s' "$notes" | grep -q '^### '; then
  notes="${notes}"$'\n\n'"### Changed"$'\n'"- No notable non-merge commits found in this range."
fi

if [[ -n "$output_path" ]]; then
  mkdir -p "$(dirname "$output_path")"
  printf '%s\n' "$notes" > "$output_path"
  printf 'Draft release notes written to %s\n' "$output_path"
else
  printf '%s\n' "$notes"
fi
