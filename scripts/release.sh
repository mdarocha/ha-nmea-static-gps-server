#!/usr/bin/env nix
#! nix shell nixpkgs#bash nixpkgs#coreutils nixpkgs#gawk nixpkgs#gh nixpkgs#git nixpkgs#gnugrep nixpkgs#gnused --command bash
# Release the app: write the changelog entry, push it, then run and follow the Release workflow.
set -euo pipefail

APP_DIR=nmea_static_gps_server
CHANGELOG="${APP_DIR}/CHANGELOG.md"

die() {
  echo "error: $*" >&2
  exit 1
}

cd "$(git rev-parse --show-toplevel)"

[[ "$(git branch --show-current)" == main ]] || die "not on main"
[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean"
git fetch --quiet --tags origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "main is not in sync with origin/main"

current=$(sed -nE 's/^version: "?([0-9]+\.[0-9]+\.[0-9]+)"?$/\1/p' "${APP_DIR}/config.yaml")
[[ -n "${current}" ]] || die "no version found in ${APP_DIR}/config.yaml"
IFS=. read -r major minor bugfix <<< "${current}"

echo "Current version: ${current}"
PS3="Bump: "
select bump in major minor bugfix; do
  case "${bump}" in
    major) version="$((major + 1)).0.0" ;;
    minor) version="${major}.$((minor + 1)).0" ;;
    bugfix) version="${major}.${minor}.$((bugfix + 1))" ;;
    *) continue ;;
  esac
  break
done

if git rev-parse --quiet --verify "refs/tags/${version}" > /dev/null; then
  die "tag ${version} already exists"
fi
if grep -qxF "## ${version}" "${CHANGELOG}"; then
  die "${CHANGELOG} already has ${version}; to retry a failed release run: gh workflow run release.yaml --ref main -f version=${version}"
fi

notes_file=$(mktemp --suffix=.md)
trap 'rm -f "${notes_file}"' EXIT
cat > "${notes_file}" << EOF
- 

# Changelog notes for ${version}, as Markdown list items.
# Lines starting with '#' are ignored. Leave empty to abort.
EOF
${EDITOR:-vi} "${notes_file}"

# $(...) already trims trailing blank lines.
notes=$(sed -e '/^#/d' -e '/^- *$/d' "${notes_file}" | awk 'NF { found = 1 } found')
[[ -n "${notes}" ]] || die "empty changelog notes, aborting"

ENTRY="## ${version}"$'\n\n'"${notes}" awk '
  !done && /^## / { print ENVIRON["ENTRY"]; print ""; done = 1 }
  { print }
  END { if (!done) { print ""; print ENVIRON["ENTRY"] } }
' "${CHANGELOG}" > "${CHANGELOG}.new"
mv "${CHANGELOG}.new" "${CHANGELOG}"

git --no-pager diff "${CHANGELOG}"
read -rp "Release ${version}? [y/N] " confirm
if [[ "${confirm}" != [yY] ]]; then
  git checkout -- "${CHANGELOG}"
  die "aborted"
fi

git commit --quiet -m "Add ${version} changelog" "${CHANGELOG}"
git push --quiet origin main

dispatch=$(gh workflow run release.yaml --ref main -f "version=${version}")
run_url=$(grep -oE 'https://\S+/actions/runs/[0-9]+' <<< "${dispatch}") || die "no run URL in gh output: ${dispatch}"
echo "Release workflow: ${run_url}"
gh run watch "${run_url##*/}" --exit-status

git pull --quiet --ff-only --tags origin main
echo "Released ${version}"
