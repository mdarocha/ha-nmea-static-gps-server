# Maintainer notes

## Releasing

Run `./scripts/release.sh` on an up-to-date `main` (needs Nix with flakes and a logged-in `gh`). It asks for the version bump, opens `$EDITOR` for the changelog notes, pushes the changelog entry and starts the **Release** workflow, then exits. The workflow builds the `amd64` and `aarch64` images, pushes them to `ghcr.io/mdarocha/nmea-static-gps-server`, sets `version` in `config.yaml`, tags that commit and creates the GitHub release from the changelog entry.

The GHCR package `nmea-static-gps-server` must be public, or Home Assistant can't pull the image.

Tags and releases are immutable: a ruleset blocks deleting or moving tags, and GitHub immutable releases are on.

If a release run fails, fix the cause and re-run the **Release** workflow from `main` with the same version.

## Testing on a device

To test changes before releasing, copy `nmea_static_gps_server` to the `local_apps` folder with `cp -rL` (its `README.md`, `DOCS.md` and `CHANGELOG.md` are symlinks into `docs/`) and remove the `image` line from its `config.yaml`, so the Supervisor builds it locally.
