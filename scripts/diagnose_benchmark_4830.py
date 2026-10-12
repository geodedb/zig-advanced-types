#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""One declared SONNY-4830 ABBA diagnostic; never selects or retries samples."""

import datetime
import hashlib
import json
import os
import resource
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from types import SimpleNamespace

BASE = Path.cwd()
OUT = BASE / "bench-diagnostic-4830"
VERSIONS = {
    "A": "04e812b675687e28bda0aec6a47d02204c3b0a13",
    "B": "9d398ad846dc7698ce504ed2bc0dfdf106139fdf",
}
RUNNER_ID = "52758884"
ORDER = ("A", "B", "B", "A")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_optional(path):
    try:
        return Path(path).read_text()
    except OSError as exc:
        return {"unavailable": str(exc)}


def snapshot():
    affinity = sorted(os.sched_getaffinity(0))
    files = [
        "/proc/loadavg",
        "/proc/stat",
        "/proc/pressure/cpu",
        "/proc/self/cgroup",
        "/sys/fs/cgroup/cpu.max",
        "/sys/fs/cgroup/cpu.stat",
        "/sys/fs/cgroup/cpuset.cpus.effective",
    ]
    processes = []
    for path in Path("/proc").glob("[0-9]*/stat"):
        try:
            raw = path.read_text()
            tail = raw[raw.rfind(")") + 2 :].split()
            if tail[0] == "R":
                processes.append(
                    {
                        "pid": int(path.parent.name),
                        "comm": raw[raw.find("(") + 1 : raw.rfind(")")],
                    }
                )
        except (OSError, IndexError, ValueError):
            continue
    return {
        "utc": datetime.datetime.now(datetime.UTC).isoformat(),
        "monotonic_ns": time.monotonic_ns(),
        "affinity": affinity,
        "files": {name: read_optional(name) for name in files},
        "visible_runnable_processes": processes,
        "frequency": {
            str(cpu): read_optional(
                f"/sys/devices/system/cpu/cpu{cpu}/cpufreq/scaling_cur_freq"
            )
            for cpu in affinity
        },
    }


def execute(label, command, cwd, env=None):
    before = snapshot()
    usage_before = resource.getrusage(resource.RUSAGE_CHILDREN)
    start = time.monotonic()
    timed_out = False
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=300,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        result = SimpleNamespace(returncode=124, stdout=exc.stdout or b"", stderr=None)
    usage_after = resource.getrusage(resource.RUSAGE_CHILDREN)
    (OUT / (label + ".log")).write_bytes(result.stdout)
    record = {
        "command": [str(item) for item in command],
        "returncode": result.returncode,
        "timed_out": timed_out,
        "elapsed_seconds": time.monotonic() - start,
        "before": before,
        "after": snapshot(),
        "child_usage_delta": {
            key: getattr(usage_after, key) - getattr(usage_before, key)
            for key in (
                "ru_utime",
                "ru_stime",
                "ru_nvcsw",
                "ru_nivcsw",
                "ru_minflt",
                "ru_majflt",
            )
        },
    }
    (OUT / (label + ".json")).write_text(json.dumps(record, indent=2) + "\n")
    return result


def main():
    OUT.mkdir(exist_ok=False)
    identity = {
        name: os.environ.get(name)
        for name in (
            "CI_RUNNER_ID",
            "CI_RUNNER_DESCRIPTION",
            "CI_RUNNER_EXECUTABLE_ARCH",
            "CI_JOB_ID",
            "CI_JOB_IMAGE",
            "CI_PIPELINE_ID",
            "CI_COMMIT_SHA",
        )
    }
    identity.update(
        cpuinfo=read_optional("/proc/cpuinfo"),
        kernel=list(os.uname()),
        zig_version=subprocess.check_output(["zig", "version"], text=True).strip(),
        zig_sha256=digest(Path(shutil.which("zig"))),
        zig_lock_sha256=digest(BASE / "ci/zig-sha256.lock"),
    )
    (OUT / "identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    assert identity["CI_RUNNER_ID"] == RUNNER_ID, (
        "Unexpected runner; no samples executed"
    )
    assert identity["zig_version"] == "0.16.0", "Unexpected toolchain"
    assert (
        "bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587"
        in identity["CI_JOB_IMAGE"]
    )
    report = {
        "versions": VERSIONS,
        "order": ORDER,
        "runs": [],
        "status": "in_progress",
        "interpretation": "Diagnostic only; every preparation and ABBA run retained. Prior required failure remains authoritative.",
    }

    def save_report():
        (OUT / "summary.json").write_text(json.dumps(report, indent=2) + "\n")

    save_report()
    with tempfile.TemporaryDirectory(prefix="at-bench-4830-") as directory:
        roots = {}
        binaries = {}
        for label, commit in VERSIONS.items():
            fetch = execute(
                "fetch-" + label, ["git", "fetch", "--no-tags", "origin", commit], BASE
            )
            assert fetch.returncode == 0
            root = Path(directory) / label
            subprocess.run(
                ["git", "worktree", "add", "--detach", str(root), commit], check=True
            )
            roots[label] = root
            files = subprocess.check_output(
                ["git", "ls-files", "src", "bench", "build.zig", "build.zig.zon", "ci"],
                cwd=root,
                text=True,
            ).splitlines()
            report.setdefault("source_hashes", {})[label] = {
                name: digest(root / name) for name in files
            }
            save_report()
            build = execute(
                "preparation-" + label,
                [
                    "zig",
                    "build",
                    "bench",
                    "-Doptimize=ReleaseFast",
                    "--cache-dir",
                    str(root / ".zig-cache"),
                    "--global-cache-dir",
                    str(root / ".global-cache"),
                ],
                root,
            )
            assert build.returncode == 0, "Build/run failed; no repeated preparation"
            matches = [
                path
                for path in (root / ".zig-cache/o").glob("*/bench")
                if path.is_file() and os.access(path, os.X_OK)
            ]
            assert len(matches) == 1, "Ambiguous benchmark executable"
            binary = matches[0]
            binaries[label] = binary
            text_section = OUT / (label + ".text")
            binary_hash = digest(binary)
            subprocess.run(
                [
                    "objcopy",
                    "--dump-section",
                    ".text=" + str(text_section),
                    str(binary),
                    str(root / "bench-inspection-copy"),
                ],
                check=True,
            )
            assert digest(binary) == binary_hash, (
                "Inspection changed the benchmark executable"
            )
            with (OUT / (label + "-disassembly.log")).open("wb") as stream:
                subprocess.run(
                    ["objdump", "-d", str(binary)], stdout=stream, check=True
                )
            report.setdefault("binaries", {})[label] = {
                "sha256": digest(binary),
                "text_sha256": digest(text_section),
            }
            save_report()
            gate = execute(
                "preparation-" + label + "-gate",
                [
                    "python3",
                    "ci/bench_gate.py",
                    "--input",
                    str(OUT / ("preparation-" + label + ".log")),
                ],
                root,
            )
            assert gate.returncode in (0, 1), "Malformed preparation measurement"
            report["runs"].append(
                {"label": "preparation-" + label, "gate": gate.returncode}
            )
            save_report()
        for index, label in enumerate(ORDER, 1):
            name = f"abba-{index}-{label}"
            measured = execute(name, [str(binaries[label])], roots[label])
            assert measured.returncode == 0, "Benchmark failed; no replacement sample"
            gate = execute(
                name + "-gate",
                ["python3", "ci/bench_gate.py", "--input", str(OUT / (name + ".log"))],
                roots[label],
            )
            assert gate.returncode in (0, 1), "Malformed measurement"
            report["runs"].append({"label": name, "gate": gate.returncode})
            save_report()
        for root in roots.values():
            subprocess.run(
                ["git", "worktree", "remove", "--force", str(root)], check=True
            )
    report["status"] = "all_declared_measurements_retained"
    (OUT / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2), flush=True)
    return int(any(run["gate"] for run in report["runs"]))


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        summary = OUT / "summary.json"
        failed = (
            json.loads(summary.read_text())
            if summary.exists()
            else {"versions": VERSIONS, "order": ORDER}
        )
        failed.update(status="diagnostic_stopped_without_replacement", error=str(exc))
        if OUT.exists():
            summary.write_text(json.dumps(failed, indent=2) + "\n")
        raise
