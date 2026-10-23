> ⚠️ **100% vibecoded codebase**

# NMEA Static GPS Server

A Home Assistant app that broadcasts your configured home location over the local network using the NMEA 0183 protocol.

Linux machines running `geoclue` can use this broadcast to determine their location when connected to your network. This lets them use the location you have already set in Home Assistant, without configuring it separately on each machine.

For more background on how this works, see [Evert Pot's blog post on broadcasting GPS data over a local network](https://evertpot.com/broadcasting-gps-on-local-network/).

## Installation

[![Open your Home Assistant instance and show the add app repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fmdarocha%2Fha-nmea-static-gps-server)

Or add `https://github.com/mdarocha/ha-nmea-static-gps-server` under **Settings** > **Apps** > **Install app** > **Repositories**, then install **NMEA Static GPS Server**. Client setup is in the [app documentation](nmea_static_gps_server/DOCS.md).

## Releasing

Run `./scripts/release.sh` on an up-to-date `main` (needs Nix with flakes and a logged-in `gh`). It asks for the version bump, opens `$EDITOR` for the changelog notes, pushes the changelog entry and follows the **Release** workflow to the end.

To release by hand instead, add a `## <version>` entry to [`nmea_static_gps_server/CHANGELOG.md`](nmea_static_gps_server/CHANGELOG.md) on `main`, then run the **Release** workflow from `main` with that version.

The workflow builds the `amd64` and `aarch64` images, pushes them to `ghcr.io/mdarocha/nmea-static-gps-server`, then sets `version` in `config.yaml`, tags the commit and creates a GitHub release. After the first release, make the `nmea-static-gps-server` package public in its GitHub package settings so Home Assistant can pull it.

To test changes on a device before releasing, copy `nmea_static_gps_server` to the `local_apps` folder and remove the `image` line from its `config.yaml`, so the Supervisor builds it locally.

## Acknowledgements

Based on [`evert/nmea-static-gps-server`](https://github.com/evert/nmea-static-gps-server) by Evert Pot. The icon is `crosshairs-gps` from [Material Design Icons](https://pictogrammers.com/library/mdi/) (Apache 2.0).
