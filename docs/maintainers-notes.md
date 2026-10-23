# Maintainer notes

## Releasing

Run `./scripts/release.sh` on an up-to-date `main` (needs Nix with flakes and a logged-in `gh`). It asks for the version bump, opens `$EDITOR` for the changelog notes, pushes the changelog entry and follows the **Release** workflow to the end.

To release by hand instead, add a `## <version>` entry to [`nmea_static_gps_server/CHANGELOG.md`](../nmea_static_gps_server/CHANGELOG.md) on `main`, then run the **Release** workflow from `main` with that version.

The workflow builds the `amd64` and `aarch64` images, pushes them to `ghcr.io/mdarocha/nmea-static-gps-server`, then sets `version` in `config.yaml`, tags the commit and creates a GitHub release. After the first release, make the `nmea-static-gps-server` package public in its GitHub package settings so Home Assistant can pull it.

## Testing on a device

To test changes before releasing, copy `nmea_static_gps_server` to the `local_apps` folder and remove the `image` line from its `config.yaml`, so the Supervisor builds it locally.
