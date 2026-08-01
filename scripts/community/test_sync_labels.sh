#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%q ' "$@"
printf '\n'
EOF
chmod +x "$tmp/bin/gh"

scripts/community/sync_labels.sh --repo EastStarAI/sanad-agent > "$tmp/dry-run"
! grep -q '^label create' "$tmp/dry-run"
grep -q 'no GitHub mutation performed' "$tmp/dry-run"

PATH="$tmp/bin:$PATH" scripts/community/sync_labels.sh \
  --repo EastStarAI/sanad-agent --apply > "$tmp/apply-1"
PATH="$tmp/bin:$PATH" scripts/community/sync_labels.sh \
  --repo EastStarAI/sanad-agent --apply > "$tmp/apply-2"
cmp "$tmp/apply-1" "$tmp/apply-2"
grep -q -- '--force' "$tmp/apply-1"
grep -q 'Applied 43 labels' "$tmp/apply-1"

echo 'Label sync dry-run and idempotency simulation passed.'
