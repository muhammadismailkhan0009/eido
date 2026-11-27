"""Drive real Linux loopback sockets; no external services or privileged setup."""
import os
import select
import socket
import subprocess
import sys
from pathlib import Path

binary = sys.argv[1]


def run(args, expected):
    result = subprocess.run([binary, *args], text=True, capture_output=True, timeout=15)
    assert result.returncode == 0 and expected in result.stdout, result
    return result


def start(args):
    process = subprocess.Popen(
        ["stdbuf", "-oL", binary, *args],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    return process


def port_from(process):
    assert select.select([process.stdout], [], [], 10)[0], "server did not announce port"
    line = process.stdout.readline().strip()
    assert line.isdecimal(), line
    return int(line)


def finish(process, expected):
    output, _ = process.communicate(timeout=10)
    assert process.returncode == 0 and expected in output, (process.returncode, output)


def cleanup(process):
    if process.poll() is None:
        process.kill()
    process.wait()


def digits(port):
    return list(f"{port:05d}")


for host in ["127.0.0.1", "::1"]:
    server = start(["server", host])
    try:
        port = port_from(server)
        run(["client", "localhost" if host == "127.0.0.1" else host, *digits(port)], "client PASS")
        finish(server, "server PASS")
    finally:
        cleanup(server)

server = start(["errors"])
try:
    port = port_from(server)
    descriptors = Path(f"/proc/{server.pid}/fd")
    sockets = [p for p in descriptors.iterdir() if os.readlink(p).startswith("socket:")]
    assert len(sockets) == 1, sockets
    with socket.create_connection(("127.0.0.1", port), timeout=2):
        pass
    finish(server, "errors PASS")
finally:
    cleanup(server)

# Force partial progress and backpressure, rather than relying on packet splitting.
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    listener.settimeout(5)
    port = listener.getsockname()[1]
    client = start(["timeouts", "127.0.0.1", *digits(port)])
    try:
        with listener.accept()[0] as peer:
            peer.sendall(b"AB")
            # Deliberately leave the read direction open and do not consume writes.
            finish(client, "timeouts PASS")
    finally:
        cleanup(client)

# A full loopback accept queue forces a genuine connect deadline.
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
    listener.bind(("127.0.0.1", 0))
    listener.listen(0)
    port = listener.getsockname()[1]
    with socket.create_connection(("127.0.0.1", port), timeout=2):
        run(["connect-timeout", "127.0.0.1", *digits(port)], "connect timeout PASS")

print("TCP loopback IPv4/IPv6, errors, lifetimes and timeouts PASS")
