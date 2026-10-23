# Maintainer notes

## Releasing

Run `./scripts/release.sh` on an up-to-date `main` (needs Nix with flakes and `gh` logged in as a repository admin). It asks for the version bump, opens `$EDITOR` for the changelog notes and pushes the changelog entry. Then it runs the **Release** workflow, which builds the `amd64` and `aarch64` images, pushes them to `ghcr.io/mdarocha/nmea-static-gps-server` and sets `version` in `config.yaml`. Finally the script tags that commit and creates the GitHub release from the changelog entry.

The GHCR package `nmea-static-gps-server` must be public, or Home Assistant can't pull the image.

Tags and releases are immutable: a ruleset blocks deleting or moving tags, only admins can create them, and GitHub immutable releases are on. Workflows can't create tags, which is why the script does it.

If the script fails after pushing the changelog, finish by hand: run the **Release** workflow from `main` with the version if it didn't succeed, then pull `main`, `git tag -a <version> -m <version>`, push the tag and `gh release create <version> --verify-tag` with the changelog entry as notes.

## Testing on a device

To test changes before releasing, copy `nmea_static_gps_server` to the `local_apps` folder with `cp -rL` (its `README.md`, `DOCS.md` and `CHANGELOG.md` are symlinks into `docs/`) and remove the `image` line from its `config.yaml`, so the Supervisor builds it locally.
