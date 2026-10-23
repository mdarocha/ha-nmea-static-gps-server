#!/usr/bin/env python3
"""Stream the Home Assistant home location as NMEA 0183 over TCP, advertised via mDNS."""

import asyncio
import json
import logging
import os
import signal
import urllib.request
from datetime import datetime, timezone

from zeroconf import ServiceInfo
from zeroconf.asyncio import AsyncZeroconf

PORT = 10110  # IANA-registered NMEA-0183 port
SERVICE_TYPE = "_nmea-0183._tcp.local."
SUPERVISOR_URL = "http://supervisor"
RETRY_DELAY = 5
SENTENCE_INTERVAL = 1

log = logging.getLogger("nmea_server")


def supervisor_get(path: str) -> dict:
    request = urllib.request.Request(
        SUPERVISOR_URL + path,
        headers={"Authorization": f"Bearer {os.environ['SUPERVISOR_TOKEN']}"},
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)


async def fetch_home() -> tuple[dict, str]:
    """Return the Core config and host name; retries, as Core may still be starting."""
    while True:
        try:
            config = await asyncio.to_thread(supervisor_get, "/core/api/config")
            info = await asyncio.to_thread(supervisor_get, "/info")
            return config, info["data"]["hostname"]
        except OSError as error:
            log.warning("Home Assistant is not reachable yet (%s), retrying in %ss", error, RETRY_DELAY)
            await asyncio.sleep(RETRY_DELAY)


def nmea_coordinate(degrees: float, degree_digits: int, hemispheres: str) -> str:
    """Format as NMEA (d)ddmm.mmmm,H; hemispheres is the positive and negative letter."""
    minutes, fraction = divmod(round(abs(degrees) * 600_000), 10_000)
    whole_degrees, minutes = divmod(minutes, 60)
    hemisphere = hemispheres[0] if degrees >= 0 else hemispheres[1]
    return f"{whole_degrees:0{degree_digits}d}{minutes:02d}.{fraction:04d},{hemisphere}"


def nmea_sentence(body: str) -> str:
    checksum = 0
    for char in body:
        checksum ^= ord(char)
    return f"${body}*{checksum:02X}\r\n"


def nmea_fix(latitude: str, longitude: str, altitude: float) -> bytes:
    now = datetime.now(timezone.utc)
    time = now.strftime("%H%M%S.000")
    date = now.strftime("%d%m%y")
    rmc = f"GPRMC,{time},A,{latitude},{longitude},0.000,0.000,{date},,"
    gga = f"GPGGA,{time},{latitude},{longitude},1,08,1.0,{altitude:.1f},M,0.0,M,,"
    return (nmea_sentence(rmc) + nmea_sentence(gga)).encode()


async def main() -> None:
    config, hostname = await fetch_home()
    latitude = nmea_coordinate(config["latitude"], 2, "NS")
    longitude = nmea_coordinate(config["longitude"], 3, "EW")
    altitude = float(config["elevation"])
    log.info(
        "Home location: lat=%.6f lon=%.6f alt=%.1fm",
        config["latitude"],
        config["longitude"],
        altitude,
    )

    async def stream(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        peer = writer.get_extra_info("peername")
        log.info("Client connected: %s", peer)
        try:
            while True:
                writer.write(nmea_fix(latitude, longitude, altitude))
                await writer.drain()
                await asyncio.sleep(SENTENCE_INTERVAL)
        except ConnectionError:
            log.info("Client disconnected: %s", peer)
        finally:
            writer.close()

    server = await asyncio.start_server(stream, port=PORT)
    log.info("Serving NMEA on port %d", PORT)

    # The host announces <hostname>.local itself, so the record carries no addresses of its own.
    service = ServiceInfo(
        SERVICE_TYPE,
        f"NMEA GPS ({config['location_name']}).{SERVICE_TYPE}",
        port=PORT,
        server=f"{hostname}.local.",
    )
    zeroconf = AsyncZeroconf()
    await zeroconf.async_register_service(service)
    log.info("Advertising %s via mDNS", service.name)

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for signum in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signum, stop.set)

    try:
        await stop.wait()
    finally:
        server.close()
        await zeroconf.async_unregister_all_services()
        await zeroconf.async_close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")
    asyncio.run(main())
