> ⚠️ **100% vibecoded codebase**

# NMEA Static GPS Server

A Home Assistant app that reads the home location configured in Home Assistant and broadcasts it as NMEA 0183 data on the local network.

The NMEA protocol is used by `geoclue` (used on Linux) to read and set the location when the machine is connected to the local network that broadcasts this protocol.

This allows you to auto-configure the location of all Linux machines on the laptop, and also re-use the settings set in Home Assistant.

## Acknowledgements

Based on [`evert/nmea-static-gps-server`](https://github.com/evert/nmea-static-gps-server) by Evert Pot.
