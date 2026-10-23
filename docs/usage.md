# Home Assistant App: NMEA Static GPS Server

## How it works

On start, the app reads the home location (latitude, longitude and elevation)
from **Settings** > **System** > **General**. It then:

- listens on TCP port 10110 and sends every connected client a GPS fix
  (`GPRMC` and `GPGGA` sentences) once per second;
- advertises the server over mDNS as `_nmea-0183._tcp`, named after your home,
  for example `NMEA GPS (Home)`.

Clients find the service via mDNS and connect to the host name of your Home
Assistant machine, such as `homeassistant.local`. Home Assistant OS announces
that name by default.

The app has no options. If you change the home location, restart the app.

## Client setup

`geoclue` has the network NMEA source enabled by default. Check that
`/etc/geoclue/geoclue.conf` contains:

```ini
[network-nmea]
enable=true
```

Then restart it and check the location it reports:

```bash
sudo systemctl restart geoclue
/usr/libexec/geoclue-2.0/demos/where-am-i
```

The location should show your home coordinates with 0 meters accuracy and the
description `GPS GGA+RMC`. The demo is in the `geoclue2-demos` package on
Fedora and `geoclue-2-demo` on Debian and Ubuntu. Some applications, like
Firefox, need a restart before they use the new location.

## Troubleshooting

Check that the service is visible from the client:

```bash
avahi-browse -rt _nmea-0183._tcp
```

Check that the stream is reachable:

```bash
nc homeassistant.local 10110
```

## Permissions

The app runs on the host network, because mDNS only reaches the local network
from there and clients connect to port 10110 on the host directly. It uses the
Home Assistant API only to read the home location.

## Support

Report issues at
<https://github.com/mdarocha/ha-nmea-static-gps-server/issues>.

## License

MIT
