# Maintainer notes

## Releasing

Run `./scripts/release.sh` on an up-to-date `main` (needs Nix with flakes and a logged-in `gh`). It asks for the version bump and opens `$EDITOR` for the changelog notes. Without a terminal it takes `--bump`, `--notes-file` and `--yes` instead; see `--help`.

The script makes one `Prepare release <version>` commit that bumps `version` in `config.yaml` and adds the changelog entry, tags it with the notes as the annotation and pushes only the tag. The tag starts the **Release** workflow, which:

1. checks that the tagged commit has the matching version and changelog entry, and sits directly ahead of `main`;
2. builds the `amd64` and `aarch64` images, pushes them to `ghcr.io/mdarocha/nmea-static-gps-server` and attests their build provenance;
3. fast-forwards `main` to the tagged commit, so Home Assistant only sees the new version once the image exists;
4. creates the GitHub release from the changelog entry.

The GHCR package `nmea-static-gps-server` must be public, or Home Assistant can't pull the image.

GitHub immutable releases are on, so a published release can't be edited. To verify a release:

```bash
gh release verify <version>
gh attestation verify oci://ghcr.io/mdarocha/nmea-static-gps-server:<version> --owner mdarocha
```

If a release run fails for a temporary reason, re-run its failed jobs. If the tagged commit itself is wrong, the tag can't be fixed: reset local `main` to `origin/main` and release the next version.

## Rulesets

| Ruleset | Applies to | Rules | Bypass |
| --- | --- | --- | --- |
| Protect tags | all tags | no deleting, updating or force-moving | nobody |
| Restrict tag creation | all tags | no creating | repository admins |
| Protect main | `main` | no deleting or force-pushing | nobody |
| Require checks on main | `main` | `Build / Lint app`, `Build / Build amd64 image` and `Build / Build aarch64 image` from GitHub Actions must pass on the commit | repository admins |

Only admins can start a release, because only they can push tags. The Release workflow can fast-forward `main` because its own build jobs report those checks on the tagged commit. Pull requests need the same checks from CI before they can be merged; admins can still push to `main` directly.

Keep those job names stable: renaming a job or the `Build` caller job in `ci.yaml` or `release.yaml` blocks merges and releases until the ruleset is updated.

## Testing on a device

To test changes before releasing, copy `nmea_static_gps_server` to the `local_apps` folder and remove the `image` line from its `config.yaml`, so the Supervisor builds it locally.
