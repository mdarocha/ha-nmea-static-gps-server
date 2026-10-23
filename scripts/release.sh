#!/usr/bin/env nix
#! nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#gawk nixpkgs#gh nixpkgs#git nixpkgs#gnugrep nixpkgs#gnused nixpkgs#gum --command bash
# Commits the version bump and changelog entry, tags it and pushes the tag; the Release workflow does the rest.
set -euo pipefail

APP_DIR=nmea_static_gps_server
CHANGELOG="${APP_DIR}/CHANGELOG.md"
CONFIG="${APP_DIR}/config.yaml"

usage() {
  cat << EOF
Usage: $0 [--bump major|minor|bugfix] [--notes-file PATH|-] [--yes]

Without options, asks for everything interactively. Without a terminal,
all three options are required.

  --bump        Version part to bump.
  --notes-file  Changelog notes as Markdown list items; '-' reads stdin.
  --yes         Release without asking for confirmation.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

interactive=false
if [[ -t 0 && -t 1 ]]; then
  interactive=true
fi

step() {
  local title=$1
  shift
  if ${interactive}; then
    gum spin --show-error --title "${title}" -- "$@"
  else
    echo "${title}"
    "$@"
  fi
}

bump=""
notes_source=""
confirmed=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) bump=${2:-}; shift 2 ;;
    --notes-file) notes_source=${2:-}; shift 2 ;;
    --yes) confirmed=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if ! ${interactive} && { [[ -z "${bump}" || -z "${notes_source}" ]] || ! ${confirmed}; }; then
  usage >&2
  die "no terminal: pass --bump, --notes-file and --yes"
fi

cd "$(git rev-parse --show-toplevel)"

[[ "$(git branch --show-current)" == main ]] || die "not on main"
[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean"
git fetch --quiet --tags origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main is not in sync with origin/main"

current=$(sed -nE 's/^version: "?([0-9]+\.[0-9]+\.[0-9]+)"?$/\1/p' "${CONFIG}")
[[ -n "${current}" ]] || die "no version found in ${CONFIG}"
IFS=. read -r major minor bugfix <<< "${current}"

if [[ -z "${bump}" ]]; then
  choice=$(gum choose --header "Current version: ${current}. Bump:" \
    "bugfix  ${major}.${minor}.$((bugfix + 1))" \
    "minor   ${major}.$((minor + 1)).0" \
    "major   $((major + 1)).0.0") || die "aborted"
  bump=${choice%% *}
fi
case "${bump}" in
  major) version="$((major + 1)).0.0" ;;
  minor) version="${major}.$((minor + 1)).0" ;;
  bugfix) version="${major}.${minor}.$((bugfix + 1))" ;;
  *) die "--bump must be major, minor or bugfix" ;;
esac

if git rev-parse --quiet --verify "refs/tags/${version}" > /dev/null; then
  die "tag ${version} already exists"
fi

notes_file=$(mktemp --suffix=.md)
trap 'rm -f "${notes_file}"' EXIT
if [[ -n "${notes_source}" ]]; then
  cat -- "${notes_source}" > "${notes_file}"
else
  cat > "${notes_file}" << EOF
- 

# Changelog notes for ${version}, as Markdown list items.
# Lines starting with '#' are ignored. Leave empty to abort.
EOF
  ${EDITOR:-vi} "${notes_file}"
fi

# $(...) already trims trailing blank lines.
notes=$(sed -e '/^#/d' -e '/^- *$/d' "${notes_file}" | awk 'NF { found = 1 } found')
[[ -n "${notes}" ]] || die "empty changelog notes, aborting"

ENTRY="## ${version}"$'\n\n'"${notes}" awk '
  !done && /^## / { print ENVIRON["ENTRY"]; print ""; done = 1 }
  { print }
  END { if (!done) { print ""; print ENVIRON["ENTRY"] } }
' "${CHANGELOG}" > "${CHANGELOG}.new"
mv "${CHANGELOG}.new" "${CHANGELOG}"
sed -i -E "s/^version: .*/version: \"${version}\"/" "${CONFIG}"

git --no-pager diff
if ! ${confirmed} && ! gum confirm "Release ${version}?" --default=false; then
  git checkout -- "${CHANGELOG}" "${CONFIG}"
  die "aborted"
fi

git commit --quiet -m "Prepare release ${version}" "${CHANGELOG}" "${CONFIG}"
git tag --annotate --cleanup=verbatim --file=- "${version}" <<< "${notes}"

# Only the tag: the Release workflow moves main to it once the images are published.
step "Pushing tag ${version}" git push --quiet origin "refs/tags/${version}"

commit=$(git rev-parse HEAD)
run_url=""
for _ in $(seq 30); do
  run_url=$(gh run list --workflow release.yaml --commit "${commit}" --json url --jq '.[0].url // empty')
  [[ -n "${run_url}" ]] && break
  sleep 2
done
[[ -n "${run_url}" ]] || die "the Release workflow did not start; check the Actions tab"

if ${interactive}; then
  gum style --foreground 2 --bold "Release ${version} started; the workflow builds and publishes it."
else
  echo "Release ${version} started; the workflow builds and publishes it."
fi
echo "Run: ${run_url}"
echo "Follow it with: gh run watch ${run_url##*/} --exit-status"
