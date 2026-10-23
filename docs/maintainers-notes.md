# Maintainer notes

## Releasing

Run `./scripts/release.sh` on an up-to-date `main` (needs Nix with flakes and a logged-in `gh`). It asks for the version bump and opens `$EDITOR` for the changelog notes. Without a terminal it takes `--bump`, `--notes-file` and `--yes` instead; see `--help`.

The script makes one `Prepare release <version>` commit that bumps `version` in `config.yaml` and adds the changelog entry, tags it with the notes as the annotation and pushes only the tag. The tag starts the **Release** workflow, which:

1. checks that the tagged commit has the matching version and changelog entry, and sits directly ahead of `main`;
2. builds the `amd64` and `aarch64` images, pushes them to `ghcr.io/mdarocha/nmea-static-gps-server` and attests their build provenance;
3. fast-forwards `main` to the tagged commit, so Home Assistant only sees the new version once the image exists;
4. creates the GitHub release from the changelog entry.

The GHCR package `nmea-static-gps-server` must be public, or Home Assistant can't pull the image.

Tags and releases are immutable: a ruleset blocks deleting or moving tags, and GitHub immutable releases are on. To verify a release:

```bash
gh release verify <version>
gh attestation verify oci://ghcr.io/mdarocha/nmea-static-gps-server:<version> --owner mdarocha
```

If a release run fails for a temporary reason, re-run its failed jobs. If the tagged commit itself is wrong, the tag can't be fixed: reset local `main` to `origin/main` and release the next version.

## Testing on a device

To test changes before releasing, copy `nmea_static_gps_server` to the `local_apps` folder and remove the `image` line from its `config.yaml`, so the Supervisor builds it locally.
