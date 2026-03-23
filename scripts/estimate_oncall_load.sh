#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/estimate_oncall_load.sh [--from <git-ref>] [--to <git-ref>]

Estimate the likely oncall load of a change set using deterministic git-based
heuristics. The score is advisory and explains the main reasons behind it.

Examples:
  scripts/estimate_oncall_load.sh
    Compare HEAD to the current working tree, including untracked files.

  scripts/estimate_oncall_load.sh --from main --to HEAD
    Compare two committed refs.

  scripts/estimate_oncall_load.sh --from HEAD
    Compare HEAD to the current working tree, including untracked files.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_value() {
  local flag="$1"
  local value="${2:-}"

  if [[ -z "${value}" ]]; then
    die "Missing value for ${flag}."
  fi
}

validate_ref() {
  local ref="$1"

  if ! git rev-parse --verify --quiet "${ref}^{object}" >/dev/null; then
    die "Invalid git ref: ${ref}"
  fi
}

classify_file() {
  local path="$1"

  case "${path}" in
    .copilot_yolo.sh|.copilot_yolo.Dockerfile|.copilot_yolo_entrypoint.sh|.copilot_yolo_config.sh|.copilot_yolo_completion.bash|.copilot_yolo_completion.zsh|install.sh|.dockerignore)
      echo 0
      ;;
    .github/workflows/*)
      echo 2
      ;;
    scripts/*)
      echo 3
      ;;
    README.md|TECHNICAL.md|CHANGELOG.md|CONTRIBUTING.md|AGENTS.md|docs/*|.pr_details/*)
      echo 4
      ;;
    *.sh|.*.sh)
      echo 1
      ;;
    *)
      echo 5
      ;;
  esac
}

append_example() {
  local current="$1"
  local value="$2"

  if [[ -z "${current}" ]]; then
    echo "${value}"
  elif [[ ",${current}," == *",${value},"* ]]; then
    echo "${current}"
  else
    echo "${current}, ${value}"
  fi
}

score_churn() {
  local churn="$1"

  if (( churn >= 600 )); then
    echo 12
  elif (( churn >= 300 )); then
    echo 9
  elif (( churn >= 120 )); then
    echo 6
  elif (( churn >= 40 )); then
    echo 3
  elif (( churn > 0 )); then
    echo 1
  else
    echo 0
  fi
}

score_breadth() {
  local files="$1"

  if (( files >= 15 )); then
    echo 9
  elif (( files >= 8 )); then
    echo 6
  elif (( files >= 4 )); then
    echo 3
  elif (( files >= 2 )); then
    echo 1
  else
    echo 0
  fi
}

score_binary() {
  local files="$1"
  local points=$(( files * 4 ))

  if (( points > 8 )); then
    points=8
  fi

  echo "${points}"
}

score_rename_only() {
  local files="$1"

  if (( files == 0 )); then
    echo 0
  elif (( files >= 4 )); then
    echo 3
  elif (( files >= 2 )); then
    echo 2
  else
    echo 1
  fi
}

risk_band() {
  local score="$1"

  if (( score <= 4 )); then
    echo "low"
  elif (( score <= 9 )); then
    echo "moderate"
  elif (( score <= 16 )); then
    echo "high"
  else
    echo "very-high"
  fi
}

summarize_status() {
  local status="$1"

  case "${status}" in
    A)
      echo "added"
      ;;
    D)
      echo "deleted"
      ;;
    R*|C*)
      echo "renamed/copied"
      ;;
    *)
      echo "modified"
      ;;
  esac
}

add_reason() {
  local label="$1"
  local points="$2"

  if (( points <= 0 )); then
    return
  fi

  reason_labels[reason_count]="${label}"
  reason_points[reason_count]="${points}"
  reason_count=$(( reason_count + 1 ))
}

record_changed_path() {
  local path="$1"
  local status="$2"
  local bucket

  bucket="$(classify_file "${path}")"
  changed_files=$(( changed_files + 1 ))
  category_files[bucket]=$(( category_files[bucket] + 1 ))
  category_examples[bucket]="$(append_example "${category_examples[bucket]}" "${path}")"

  if (( bucket != docs_bucket )); then
    non_doc_changes=$(( non_doc_changes + 1 ))
  fi

  case "${status}" in
    R*|C*)
      rename_candidates=$(( rename_candidates + 1 ))
      ;;
  esac
}

from_ref=""
to_ref=""

while (($# > 0)); do
  case "$1" in
    --from)
      require_value "--from" "${2:-}"
      from_ref="$2"
      shift 2
      ;;
    --to)
      require_value "--to" "${2:-}"
      to_ref="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  die "This command must be run inside a git repository."
fi

if [[ -n "${from_ref}" ]]; then
  validate_ref "${from_ref}"
fi

if [[ -n "${to_ref}" ]]; then
  validate_ref "${to_ref}"
fi

if [[ -z "${from_ref}" && -z "${to_ref}" ]]; then
  if git rev-parse --verify --quiet "HEAD^{object}" >/dev/null; then
    from_ref="HEAD"
  else
    die "HEAD is unavailable; provide --from and --to explicitly."
  fi
fi

if [[ -z "${from_ref}" && -n "${to_ref}" ]]; then
  if git rev-parse --verify --quiet "HEAD^{object}" >/dev/null; then
    from_ref="HEAD"
  else
    die "HEAD is unavailable; provide --from when using --to."
  fi
fi

compare_working_tree=0
range_label=""
diff_mode=""
diff_args=()

if [[ -n "${to_ref}" ]]; then
  diff_args=("${from_ref}" "${to_ref}")
  diff_mode="committed refs"
  range_label="${from_ref}..${to_ref}"
else
  diff_args=("${from_ref}")
  compare_working_tree=1
  diff_mode="working tree"
  range_label="${from_ref}..working-tree"
fi

category_names=(
  "distributed runtime"
  "core shell"
  "ci"
  "auxiliary scripts"
  "docs"
  "other"
)
category_weights=(10 7 6 4 1 3)
category_caps=(20 14 12 8 3 9)
category_files=(0 0 0 0 0 0)
category_points=(0 0 0 0 0 0)
category_examples=("" "" "" "" "" "")
docs_bucket=4

changed_files=0
non_doc_changes=0
rename_candidates=0
rename_only_files=0
binary_files=0
total_additions=0
total_deletions=0
reason_count=0
reason_labels=()
reason_points=()
docs_only_note=""

while IFS=$'\t' read -r status path_a path_b; do
  local_path=""

  if [[ -z "${status}${path_a}${path_b}" ]]; then
    continue
  fi

  if [[ -n "${path_b}" ]]; then
    local_path="${path_b}"
  else
    local_path="${path_a}"
  fi

  record_changed_path "${local_path}" "${status}"
done < <(git diff --name-status -M --find-renames "${diff_args[@]}" --)

while IFS=$'\t' read -r added deleted _; do
  if [[ -z "${added}${deleted}" ]]; then
    continue
  fi

  if [[ "${added}" == "-" || "${deleted}" == "-" ]]; then
    binary_files=$(( binary_files + 1 ))
    continue
  fi

  total_additions=$(( total_additions + added ))
  total_deletions=$(( total_deletions + deleted ))
done < <(git diff --numstat -M --find-renames "${diff_args[@]}" --)

if (( compare_working_tree == 1 )); then
  while IFS= read -r untracked_path; do
    numstat_line=""
    added=""
    deleted=""

    if [[ -z "${untracked_path}" ]]; then
      continue
    fi

    record_changed_path "${untracked_path}" "A"

    numstat_line="$(git diff --no-index --numstat -- /dev/null "${untracked_path}" 2>/dev/null || true)"
    IFS=$'\t' read -r added deleted _ <<EOF || true
${numstat_line}
EOF

    if [[ "${added}" == "-" || "${deleted}" == "-" ]]; then
      binary_files=$(( binary_files + 1 ))
      continue
    fi

    if [[ -n "${added}" ]]; then
      total_additions=$(( total_additions + added ))
    fi
    if [[ -n "${deleted}" ]]; then
      total_deletions=$(( total_deletions + deleted ))
    fi
  done < <(git ls-files --others --exclude-standard)
fi

total_churn=$(( total_additions + total_deletions ))

if (( changed_files == 0 )); then
  echo "ONCALL LOAD SCORE: 0"
  echo "RISK BAND: low"
  echo "Diff mode: ${diff_mode}"
  echo "Range: ${range_label}"
  echo "Changed files: 0"
  echo "Total churn: +0/-0 (0 lines)"
  echo "Binary files: 0"
  echo "Rename-only files: 0"
  echo
  echo "Area breakdown:"
  echo "  - no changed files detected"
  echo
  echo "Top reasons:"
  echo "  - No risk drivers detected."
  exit 0
fi

if (( rename_candidates > 0 && total_churn == 0 )); then
  rename_only_files="${rename_candidates}"
fi

for i in "${!category_names[@]}"; do
  raw_points=$(( category_files[i] * category_weights[i] ))
  if (( raw_points > category_caps[i] )); then
    raw_points="${category_caps[i]}"
  fi
  category_points[i]="${raw_points}"
done

score=0
for points in "${category_points[@]}"; do
  score=$(( score + points ))
done

churn_points="$(score_churn "${total_churn}")"
breadth_points="$(score_breadth "${changed_files}")"
binary_points="$(score_binary "${binary_files}")"
rename_points="$(score_rename_only "${rename_only_files}")"

score=$(( score + churn_points + breadth_points + binary_points + rename_points ))

for i in "${!category_names[@]}"; do
  add_reason "Touched ${category_names[i]} paths (${category_examples[i]}): +${category_points[i]}" "${category_points[i]}"
done

add_reason "Total churn is ${total_churn} lines: +${churn_points}" "${churn_points}"
add_reason "Change spread covers ${changed_files} files: +${breadth_points}" "${breadth_points}"
add_reason "Includes ${binary_files} binary files: +${binary_points}" "${binary_points}"
add_reason "Contains ${rename_only_files} rename-only file moves: +${rename_points}" "${rename_points}"

if (( non_doc_changes == 0 && score > 4 )); then
  score=4
  docs_only_note="Docs-only change set detected; score capped at the low band."
fi

band="$(risk_band "${score}")"

echo "ONCALL LOAD SCORE: ${score}"
echo "RISK BAND: ${band}"
echo "Diff mode: ${diff_mode}"
echo "Range: ${range_label}"
echo "Changed files: ${changed_files}"
echo "Total churn: +${total_additions}/-${total_deletions} (${total_churn} lines)"
echo "Binary files: ${binary_files}"
echo "Rename-only files: ${rename_only_files}"

if [[ -n "${docs_only_note}" ]]; then
  echo "Notes: ${docs_only_note}"
fi

echo
echo "Area breakdown:"
for i in "${!category_names[@]}"; do
  if (( category_files[i] == 0 )); then
    continue
  fi

  echo "  - ${category_names[i]}: ${category_files[i]} file(s), +${category_points[i]} (${category_examples[i]})"
done

echo
echo "Top reasons:"
printed=0
used_flags=()
for i in "${!reason_labels[@]}"; do
  used_flags[i]=0
done

while (( printed < 3 && printed < reason_count )); do
  best_index=-1
  best_points=-1

  for i in "${!reason_labels[@]}"; do
    if (( used_flags[i] == 0 && reason_points[i] > best_points )); then
      best_index="${i}"
      best_points="${reason_points[i]}"
    fi
  done

  if (( best_index < 0 )); then
    break
  fi

  echo "  - ${reason_labels[best_index]}"
  used_flags[best_index]=1
  printed=$(( printed + 1 ))
done

if (( reason_count == 0 )); then
  echo "  - No risk drivers detected."
fi
