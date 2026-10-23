# AGENTS.md

Home Assistant app repository with one app, `nmea_static_gps_server/`. The app reads the home location from Home Assistant Core, streams it as NMEA 0183 (GPRMC + GPGGA, once per second) on TCP 10110 and advertises `_nmea-0183._tcp` over mDNS for `geoclue`. Based on [`evert/nmea-static-gps-server`](https://github.com/evert/nmea-static-gps-server); keep the app that small.

## Layout

- `repository.yaml`: app repository metadata for the Supervisor.
- `nmea_static_gps_server/config.yaml`: app manifest. Change `version` only through `scripts/release.sh`.
- `nmea_static_gps_server/nmea_server.py`: the whole app. Python stdlib plus `zeroconf` from Alpine's `py3-zeroconf`.
- `nmea_static_gps_server/{README,DOCS,CHANGELOG}.md`: shown by Home Assistant on the store page, the Documentation tab and in update dialogs. They must be regular files in the app folder.
- `docs/maintainers-notes.md`: release and testing notes for humans.
- `.github/workflows/`: `ci.yaml` (lint + test build), `build.yaml` (reusable multi-arch build with provenance attestation), `release.yaml` (runs on tag push).
- `scripts/release.sh`: prepares, tags and pushes a release.

## Design constraints

- The mDNS record has no addresses. Its SRV target is `<host hostname>.local`, which Home Assistant OS announces itself through systemd-resolved. Don't publish A records from the app: they would clash with the host's.
- The hostname comes from the Supervisor `/info` endpoint; the location from `/core/api/config` (`homeassistant_api: true`). Both go through `http://supervisor` with `SUPERVISOR_TOKEN`.
- `host_network: true` is required for mDNS on the LAN.
- The image is plain `alpine` with Docker's init (`init` left at its default). Don't switch to the Home Assistant base image: its S6 init drops the container environment, including `SUPERVISOR_TOKEN`, for `CMD`.
- Home Assistant docs for apps: <https://contributors.home-assistant.io/apps/>.

## Checks

```bash
nix run nixpkgs#actionlint -- .github/workflows/*.yaml
bash -n scripts/release.sh
podman build --from docker.io/library/alpine:3.24 -t nmea-test nmea_static_gps_server
```

Podman can't resolve the short name `alpine:3.24` here, hence `--from`; Docker and the Supervisor resolve it fine.

The app linter CI uses is `frenck/action-addon-linter`. To run it locally, build its `src/Dockerfile` and run it with `INPUT_PATH=./nmea_static_gps_server INPUT_COMMUNITY=false`.

## Smoke test without Home Assistant

Rootless containers can't bind port 80 on the host network, so fake the Supervisor as an HTTP proxy: `urllib` honours `http_proxy`, and the proxy receives absolute URLs like `http://supervisor/core/api/config`.

1. Run a small HTTP server on `127.0.0.1:18080`. It answers `http://supervisor/core/api/config` with `{"latitude":…,"longitude":…,"elevation":…,"location_name":…}` and `http://supervisor/info` with `{"data":{"hostname":"<this machine's hostname>"}}`.
2. `podman run --rm --init --network host -e SUPERVISOR_TOKEN=test -e http_proxy=http://127.0.0.1:18080 nmea-test`
3. Check the stream with `nc 127.0.0.1 10110` and the record with `avahi-browse -rt _nmea-0183._tcp`. Resolving needs something answering `<hostname>.local`; a local avahi with `publish-addresses=no` won't.

## Releasing

Releases are immutable (immutable releases on, tag ruleset blocks deleting or moving tags), so a published version can't be fixed, only superseded. Release only when asked, from a clean `main` in sync with `origin`:

```bash
printf -- '- What changed.\n' | ./scripts/release.sh --bump bugfix --notes-file - --yes
gh run watch <run id printed by the script> --exit-status
gh release verify <version>
gh attestation verify oci://ghcr.io/mdarocha/nmea-static-gps-server:<version> --owner mdarocha
```

Notes are Markdown list items for users of the app. The script commits them to `CHANGELOG.md` together with the `config.yaml` version bump, tags that commit and pushes only the tag. The Release workflow builds and attests the images, fast-forwards `main` to the tag and creates the GitHub release. Until it finishes, local `main` is ahead of `origin/main`; that is expected.
