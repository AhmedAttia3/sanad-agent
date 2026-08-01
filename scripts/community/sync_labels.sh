#!/usr/bin/env bash
set -euo pipefail

repo=""
apply=false
manifest=".github/labels.yml"

usage() {
  cat <<'EOF'
Usage: scripts/community/sync_labels.sh --repo OWNER/REPO [--apply] [--manifest PATH]

Validates the versioned label catalog and prints the idempotent changes by default.
Pass --apply only after the target repository and current diff have been reviewed.
The command creates or updates catalog labels; it never deletes remote labels.
EOF
}

while (($#)); do
  case "$1" in
    --repo) repo="${2:?missing repository}"; shift 2 ;;
    --manifest) manifest="${2:?missing manifest}"; shift 2 ;;
    --apply) apply=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$repo" ]] || { echo "--repo OWNER/REPO is required" >&2; exit 2; }
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || {
  echo "Invalid repository: $repo" >&2
  exit 2
}
[[ -f "$manifest" ]] || { echo "Manifest not found: $manifest" >&2; exit 2; }

ruby scripts/community/validate_governance.rb --labels-only "$manifest"

mapfile_command=(ruby -ryaml -e '
data = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false)
data.fetch("labels").each do |label|
  puts [label.fetch("name"), label.fetch("color"), label.fetch("description")].join("\t")
end
' "$manifest")

count=0
while IFS=$'\t' read -r name color description; do
  ((count+=1))
  if [[ "$apply" == true ]]; then
    gh label create "$name" --repo "$repo" --color "$color" \
      --description "$description" --force
  else
    printf 'would upsert label %q in %s (color=%s)\n' "$name" "$repo" "$color"
  fi
done < <("${mapfile_command[@]}")

if [[ "$apply" == true ]]; then
  echo "Applied $count labels to $repo without deleting unmanaged labels."
else
  echo "Dry run: $count labels validated; no GitHub mutation performed."
fi
