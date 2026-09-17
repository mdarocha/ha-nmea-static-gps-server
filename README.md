> ⚠️ **100% vibecoded codebase**

# NMEA Static GPS Server

A Home Assistant app that broadcasts your configured home location over the local network using the NMEA 0183 protocol.

Linux machines running `geoclue` can use this broadcast to determine their location when connected to your network. This lets them use the location you have already set in Home Assistant, without configuring it separately on each machine.

For more background on how this works, see [Evert Pot's blog post on broadcasting GPS data over a local network](https://evertpot.com/broadcasting-gps-on-local-network/).

## Acknowledgements

Based on [`evert/nmea-static-gps-server`](https://github.com/evert/nmea-static-gps-server) by Evert Pot.
