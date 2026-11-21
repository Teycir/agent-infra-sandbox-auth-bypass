#!/usr/bin/env python3
"""Minimal trusted-stage Chromium supervisor.

The process is started by gem_init.sh before runtime restrictions are applied.
It waits for gem.sh to publish the runtime config and for the X display socket
to become usable, then owns Chromium for the container lifetime.
"""

from __future__ import annotations

import errno
import http.client
import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
from collections.abc import Mapping, Sequence
from typing import Any


CONFIG_PATH = "/var/run/gem/browser-supervisor.json"
DEFAULT_PID_FILE = "/var/run/gem/browser.pid"
DEFAULT_RESTART_DELAY_SECONDS = 1.0
DEFAULT_CONFIG_RETRY_SECONDS = 0.5
DEFAULT_DISPLAY_TIMEOUT_SECONDS = 120.0
DEFAULT_DISPLAY_PROBE_TIMEOUT_SECONDS = 1.0
DEFAULT_STARTUP_TIMEOUT_SECONDS = 30.0


def log(message: str) -> None:
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"{timestamp} INFO browser-supervisor: {message}", flush=True)


def load_config(path: str = CONFIG_PATH) -> dict[str, Any]:
    with open(path, encoding="utf-8") as f:
        config = json.load(f)
    if not isinstance(config, dict):
        raise ValueError("browser supervisor config must be a JSON object")
    return config


def display_number(display: str) -> int:
    match = re.search(r":(?P<number>\d+)(?:\.\d+)?$", display.strip())
    if not match:
        raise ValueError(f"unsupported DISPLAY value: {display!r}")
    return int(match.group("number"))


def display_socket_path(display: str) -> str:
    return f"/tmp/.X11-unix/X{display_number(display)}"


def socket_connects(path: str, timeout: float) -> bool:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        client.settimeout(timeout)
        client.connect(path)
        return True
    except OSError as exc:
        if exc.errno not in (
            errno.ENOENT,
            errno.ECONNREFUSED,
            errno.EACCES,
            errno.EAGAIN,
        ):
            log(f"display socket probe failed for {path}: {exc}")
        return False
    finally:
        client.close()


def wait_for_display(display_cfg: Mapping[str, Any], stopping) -> None:
    display = str(display_cfg.get("value") or os.environ.get("DISPLAY") or ":99.0")
    path = display_socket_path(display)
    timeout = float(display_cfg.get("ready_timeout_seconds", DEFAULT_DISPLAY_TIMEOUT_SECONDS))
    probe_timeout = float(
        display_cfg.get("probe_timeout_seconds", DEFAULT_DISPLAY_PROBE_TIMEOUT_SECONDS)
    )
    deadline = time.monotonic() + timeout
    log(f"waiting for display {display} at {path}")
    while not stopping():
        if os.path.exists(path) and socket_connects(path, probe_timeout):
            log(f"display ready: {display}")
            return
        if time.monotonic() >= deadline:
            raise TimeoutError(f"display {display} not ready after {timeout}s")
        time.sleep(0.25)
    raise InterruptedError("stopping while waiting for display")


def has_user_data_dir_arg(args: Sequence[str]) -> bool:
    return any(arg == "--user-data-dir" or arg.startswith("--user-data-dir=") for arg in args)


def effective_user_data_dir(args: Sequence[str], default_dir: str) -> str:
    current = default_dir
    iterator = iter(range(len(args)))
    for index in iterator:
        arg = args[index]
        if arg.startswith("--user-data-dir="):
            current = arg.split("=", 1)[1]
        elif arg == "--user-data-dir" and index + 1 < len(args):
            current = args[index + 1]
    return current


def set_arg_value(args: Sequence[str], name: str, value: str) -> list[str]:
    prefix = name + "="
    result = []
    found = False
    skip_next = False
    for index, arg in enumerate(args):
        if skip_next:
            skip_next = False
            continue
        if arg == name:
            result.append(f"{name}={value}")
            found = True
            if index + 1 < len(args):
                skip_next = True
            continue
        if arg.startswith(prefix):
            result.append(f"{name}={value}")
            found = True
            continue
        result.append(arg)
    if not found:
        result.append(f"{name}={value}")
    return result


def browser_argv(browser_cfg: Mapping[str, Any]) -> list[str]:
    binary = str(browser_cfg.get("binary") or "/usr/local/bin/browser")
    args = [str(arg) for arg in browser_cfg.get("args", [])]
    user_data_dir = str(browser_cfg.get("user_data_dir") or "/home/gem/.config/browser")
    if not has_user_data_dir_arg(args):
        args = [f"--user-data-dir={user_data_dir}", *args]
    cdp_port = str(browser_cfg.get("cdp_port") or 9222)
    args = set_arg_value(args, "--remote-debugging-port", cdp_port)
    return [binary, *args]


def ensure_dir_for_user(path: str, uid: int, gid: int) -> None:
    os.makedirs(path, exist_ok=True)
    os.chown(path, uid, gid)


def write_pid_file(path: str, pid: int, gid: int) -> None:
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    tmp_path = f"{path}.tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(f"{pid}\n")
    os.chown(tmp_path, 0, gid)
    os.chmod(tmp_path, 0o640)
    os.replace(tmp_path, path)


def remove_pid_file(path: str, pid: int | None = None) -> None:
    try:
        with open(path, encoding="utf-8") as f:
            current = int(f.read().strip())
    except (OSError, ValueError):
        current = None
    if pid is None or current == pid:
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass


def drop_privileges(username: str, uid: int, gid: int):
    def demote() -> None:
        os.initgroups(username, gid)
        os.setgid(gid)
        os.setuid(uid)

    return demote


def wait_for_cdp(process: subprocess.Popen[Any], host: str, port: int, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            return False
        conn = None
        try:
            conn = http.client.HTTPConnection(host, port, timeout=1)
            conn.request("GET", "/json/version")
            response = conn.getresponse()
            response.read()
            if response.status == 200:
                return True
        except OSError:
            pass
        except http.client.HTTPException:
            pass
        finally:
            if conn is not None:
                conn.close()
        time.sleep(0.5)
    return False


def terminate_process(process: subprocess.Popen[Any], timeout: float = 10.0) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    except OSError:
        process.terminate()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            return
        time.sleep(0.2)
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    except OSError:
        process.kill()


class BrowserSupervisor:
    def __init__(self, config_path: str = CONFIG_PATH) -> None:
        self.config_path = config_path
        self.stopping = False
        self.browser: subprocess.Popen[Any] | None = None
        signal.signal(signal.SIGTERM, self._handle_signal)
        signal.signal(signal.SIGINT, self._handle_signal)

    def _handle_signal(self, signum, _frame) -> None:
        log(f"received signal {signum}, shutting down")
        self.stopping = True
        if self.browser is not None:
            terminate_process(self.browser)

    def should_stop(self) -> bool:
        return self.stopping

    def wait_config(self) -> dict[str, Any]:
        log(f"waiting for config {self.config_path}")
        last_error = ""
        while not self.stopping:
            try:
                return load_config(self.config_path)
            except FileNotFoundError:
                pass
            except (json.JSONDecodeError, ValueError, OSError) as exc:
                current = str(exc)
                if current != last_error:
                    log(f"config not ready: {current}")
                    last_error = current
            time.sleep(DEFAULT_CONFIG_RETRY_SECONDS)
        raise InterruptedError("stopping while waiting for config")

    def launch_once(self, config: Mapping[str, Any]) -> None:
        user_cfg = config.get("user") or {}
        browser_cfg = config.get("browser") or {}
        path_cfg = config.get("paths") or {}
        restart_cfg = config.get("restart") or {}

        username = str(user_cfg.get("name") or "gem")
        uid = int(user_cfg.get("uid") or 1000)
        gid = int(user_cfg.get("gid") or 1000)
        argv = browser_argv(browser_cfg)
        default_user_data_dir = str(browser_cfg.get("user_data_dir") or f"/home/{username}/.config/browser")
        profile_dir = effective_user_data_dir(argv[1:], default_user_data_dir)
        pid_file = str(path_cfg.get("pid_file") or DEFAULT_PID_FILE)
        browser_log_path = str(path_cfg.get("browser_log_file") or "/var/log/gem/browser.log")
        startup_timeout = float(
            restart_cfg.get("startup_timeout_seconds", DEFAULT_STARTUP_TIMEOUT_SECONDS)
        )

        ensure_dir_for_user(profile_dir, uid, gid)
        log_dir = os.path.dirname(browser_log_path)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
        env = os.environ.copy()
        env.update({str(key): str(value) for key, value in (browser_cfg.get("env") or {}).items()})

        log(f"starting Chromium: pid_file={pid_file} profile={profile_dir}")
        remove_pid_file(pid_file)
        with open(browser_log_path, "ab", buffering=0) as browser_log:
            process = subprocess.Popen(
                argv,
                stdin=subprocess.DEVNULL,
                stdout=browser_log,
                stderr=subprocess.STDOUT,
                env=env,
                cwd=env.get("HOME", f"/home/{username}"),
                preexec_fn=drop_privileges(username, uid, gid),
                start_new_session=True,
            )
            self.browser = process
            host = str(browser_cfg.get("cdp_host") or "127.0.0.1")
            port = int(browser_cfg.get("cdp_port") or 9222)
            if not wait_for_cdp(process, host, port, startup_timeout):
                if process.poll() is None:
                    log(f"Chromium did not expose CDP within {startup_timeout}s, restarting")
                    terminate_process(process)
                else:
                    log(f"Chromium exited before CDP became ready: rc={process.returncode}")
                remove_pid_file(pid_file, process.pid)
                self.browser = None
                return
            write_pid_file(pid_file, process.pid, gid)
            log(f"Chromium ready on {host}:{port}, pid={process.pid}")
            process.wait()
            log(f"Chromium exited: pid={process.pid} rc={process.returncode}")
            remove_pid_file(pid_file, process.pid)
            self.browser = None

    def run(self) -> int:
        while not self.stopping:
            config: Mapping[str, Any] = {}
            try:
                config = self.wait_config()
                wait_for_display(config.get("display") or {}, self.should_stop)
                self.launch_once(config)
            except InterruptedError:
                break
            except Exception as exc:  # noqa: BLE001 - keep trusted helper alive.
                log(f"supervisor loop error: {exc}")

            delay = DEFAULT_RESTART_DELAY_SECONDS
            try:
                delay = float((config.get("restart") or {}).get("delay_seconds", delay))
            except Exception:
                pass
            if not self.stopping:
                time.sleep(max(delay, 0.1))
        return 0


def main() -> int:
    config_path = sys.argv[1] if len(sys.argv) > 1 else CONFIG_PATH
    return BrowserSupervisor(config_path).run()


if __name__ == "__main__":
    raise SystemExit(main())
