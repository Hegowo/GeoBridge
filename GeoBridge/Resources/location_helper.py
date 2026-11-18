#!/usr/bin/env python3
import asyncio
import inspect
import sys

TUNNEL_WAIT_SECONDS = 20
TUNNEL_POLL_SECONDS = 1
TUNNELD_ADDRESS = ("127.0.0.1", 49151)


def log(message):
    sys.stderr.write(f"{message}\n")
    sys.stderr.flush()


async def resolve(value):
    if inspect.isawaitable(value):
        return await value
    return value


def tunneld_endpoints(udid):
    import json
    import urllib.request

    with urllib.request.urlopen(f"http://{TUNNELD_ADDRESS[0]}:{TUNNELD_ADDRESS[1]}/", timeout=3) as response:
        tunnels = json.load(response)
    if udid:
        entries = tunnels.get(udid, [])
    else:
        entries = [entry for device_entries in tunnels.values() for entry in device_entries]
    return [(entry["tunnel-address"], entry["tunnel-port"]) for entry in entries]


async def connect_rsd(endpoints):
    from pymobiledevice3.remote.remote_service_discovery import RemoteServiceDiscoveryService

    last_error = None
    for endpoint in endpoints:
        rsd = RemoteServiceDiscoveryService(endpoint)
        try:
            await rsd.connect()
            return rsd
        except Exception as e:
            last_error = e
    raise RuntimeError(f"tunnel found but RSD connection failed: {type(last_error).__name__}: {last_error}")


async def get_service_provider(udid, wait_for_tunnel):
    deadline = asyncio.get_running_loop().time() + (TUNNEL_WAIT_SECONDS if wait_for_tunnel else 0)
    last_error = None
    while True:
        try:
            endpoints = tunneld_endpoints(udid)
            if endpoints:
                return await connect_rsd(endpoints)
            last_error = "device not exposed by tunneld yet"
        except OSError as e:
            last_error = f"tunneld unreachable: {e}"
        if asyncio.get_running_loop().time() >= deadline:
            break
        await asyncio.sleep(TUNNEL_POLL_SECONDS)

    log(f"tunneld: {last_error}")
    from pymobiledevice3.lockdown import create_using_usbmux
    return await resolve(create_using_usbmux(serial=udid))


async def stdin_lines():
    loop = asyncio.get_running_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)
    while True:
        raw = await reader.readline()
        if not raw:
            break
        yield raw.decode("utf-8", errors="replace").strip()


async def main() -> None:
    udid = sys.argv[1] if len(sys.argv) > 1 else None
    wait_for_tunnel = "--no-tunnel-wait" not in sys.argv[2:]

    from pymobiledevice3.services.dvt.instruments.dvt_provider import DvtProvider
    from pymobiledevice3.services.dvt.instruments.location_simulation import LocationSimulation

    provider = await get_service_provider(udid, wait_for_tunnel)

    async with DvtProvider(provider) as dvt:
        async with LocationSimulation(dvt) as loc:
            sys.stdout.write("READY\n")
            sys.stdout.flush()

            async for line in stdin_lines():
                if line == "STOP":
                    break
                if "," not in line:
                    continue
                try:
                    lat_s, lon_s = line.split(",", 1)
                    await loc.set(float(lat_s.strip()), float(lon_s.strip()))
                except Exception as e:
                    log(f"WARN: {e}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except (KeyboardInterrupt, SystemExit):
        pass
    except Exception as e:
        log(f"FATAL: {type(e).__name__}: {e}".rstrip(": "))
        sys.exit(1)
