"""Measure a copied DLL's real synchronous export and subsequent status read."""
import argparse
import ctypes
import json
import re
import statistics
import time
from pathlib import Path

arguments = argparse.ArgumentParser()
arguments.add_argument("directory", type=Path)
arguments.add_argument("--iterations", type=int, default=500)
args = arguments.parse_args()
root = args.directory.resolve()
library = ctypes.WinDLL(str(root / "ZoneFPVNative.dll"))
poll = library.zonefpv_resources_poll
poll.argtypes = [ctypes.c_void_p]
poll.restype = ctypes.c_int
samples = []
poll_samples = []
read_samples = []
previous = 0
for index in range(args.iterations + 10):
    start = time.perf_counter_ns()
    poll(None)
    published = time.perf_counter_ns()
    with (root / "native-resources-status.txt").open("rb") as file:
        packet = file.read(161)
    match = re.fullmatch(rb"ZFPVR11 (\d+) (\d+) (\d+) 0 0 0\n", packet)
    if not match or int(match[1]) != previous + 1:
        raise RuntimeError(f"Invalid/stale resource packet: {packet!r}")
    previous = int(match[1])
    elapsed = (time.perf_counter_ns() - start) / 1e6
    if index >= 10:
        samples.append(elapsed)
        poll_samples.append((published - start) / 1e6)
        read_samples.append(elapsed - poll_samples[-1])
report = {
    "offline_only": True,
    "gameplay_verified": False,
    "game_object_array_available": False,
    "iterations": len(samples),
    "mean_ms": statistics.mean(samples),
    "median_ms": statistics.median(samples),
    "p95_ms": sorted(samples)[int(len(samples) * .95)],
    "max_ms": max(samples),
    "native_poll_mean_ms": statistics.mean(poll_samples),
    "subsequent_reader_mean_ms": statistics.mean(read_samples),
    "includes": "Native memory query, synchronous file publication and status read",
}
(root / "resource-poll-benchmark.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report))
