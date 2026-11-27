# TCP networking

The initial provider uses Linux sockets for TCP/IP and ordinary Eido code for
resource orchestration, options, validation and complete-transfer loops. No
default arguments, field defaults, overloads, scheduler, exceptions or protocol
implementation were added. The unused experimental frame APIs have been removed.

## Public API

All declarations have canonical owner module `eido.stdlib.network`; semantic
directories are not submodules. The network manifest discovers its sources
with `sources: [.]` and explicitly adopts the declarations used across immediate
directory subtrees; these internal adoptions do not expose provider classes
publicly. Import nominal declarations explicitly as needed.
Export roots: Tcp, TcpConnection, TcpListener and NetworkStatus. The address, option and result classes are visible through the API
signature closure. Only the owner explicitly authorizes external implementations
of TcpConnection and TcpListener. Concrete OS providers and their
native bridge are hidden.

```eido
Tcp.connect(SocketAddress address, TcpClientOptions options)
    returns TcpConnectionResult;
Tcp.listen(SocketAddress address, TcpListenOptions options)
    returns TcpListenerResult;

interface TcpListener {
    function accept() returns TcpConnectionResult;
    function localAddress() returns SocketAddress;
    function close();
}

interface TcpConnection {
    function read(Storage<Byte> buffer) returns Int;
    function readExactly(Storage<Byte> buffer) returns TransferResult;
    function write(Storage<Byte> buffer) returns Int;
    function writeAll(Storage<Byte> buffer) returns TransferResult;
    function localAddress() returns SocketAddress;
    function remoteAddress() returns SocketAddress;
    function shutdownWrite() returns Int;
    function close();
}
```

SocketAddress contains String host and Int port. Hostnames and numeric IPv4/IPv6
addresses are resolved by the OS. An empty listen host asks the OS for a wildcard
address; a listener binds one resolved endpoint (not all resolved addresses).
Use explicit loopback addresses for local-only servers. Port 0 requests an
ephemeral listen port, reported by localAddress(). Connect ports must be 1–65535.
Endpoint snapshots contain numeric address strings, not reverse DNS names.

## Configuration

Every defaults() call constructs a fresh object graph; fields can be initialized
explicitly or modified through class-owned setter methods. Factories validate
raw constructed options as well as setter contracts. Values are captured on
acquisition; changing options later does not alter established resources.

| Class | Fields and defaults |
| --- | --- |
| TcpClientOptions | connectTimeoutMs=0, connectionOptions=TcpConnectionOptions.defaults() |
| TcpListenOptions | backlog=128, acceptTimeoutMs=0, connectionOptions=TcpConnectionOptions.defaults() |
| TcpConnectionOptions | readTimeoutMs=0, writeTimeoutMs=0, noDelay=false, keepAlive=false |

Timeouts are nonnegative milliseconds; zero is indefinite. The connect timeout
covers the resolved address attempts, excluding blocking OS name resolution.
Accept and each underlying read/write have their own monotonic deadline. A
complete-transfer call can exceed that timeout across multiple successful
partial operations. Backlog is a requested pending-connection queue limit, not
the number of active clients. The OS may cap it.

```eido
import eido.stdlib.network.Tcp;
import eido.stdlib.network.SocketAddress;
import eido.stdlib.network.TcpClientOptions;
import eido.stdlib.network.NetworkStatus;
import eido.stdlib.storage.Storage;
import eido.stdlib.io.Console;

function main() {
    var address = SocketAddress { host = "127.0.0.1"; port = 8080; };
    var options = TcpClientOptions.defaults();
    options.setConnectTimeout(5000);
    options.connectionOptions.setReadTimeout(3000);
    options.connectionOptions.setNoDelay(true);
    var opened = Tcp.connect(address, options);
    if (opened.status != NetworkStatus.success()) {
        Console.errorLine("Connect failed");
        return;
    }
    if opened.connection exists {
        var connection = opened.connection;
        var data = Storage<Byte>.allocate(1);
        Storage<Byte>.write(data, 0, 42);
        var sent = connection.writeAll(data);
        if (sent.status != NetworkStatus.success()) {
            Console.errorLine("Write failed");
        }
        connection.close();
        Storage<Byte>.release(data);
    }
}
```

See tests/integration/tcp_networking for executable server and client examples.
The lexical exists proof form does not have an else branch; check status or
return after the proof block.

## Transfer and lifetime contract

Read/write use the entire live contiguous Storage<Byte> region (stride 1).
Slice to select a smaller region. No intermediate user-space byte buffer or
per-transfer backing allocation is required by the native I/O path. Normal
socket I/O still crosses the kernel boundary. Native memory access requires
valid lifetime and address; released or otherwise invalid Storage is a
programming error, not an ordinary networking status.

Positive read/write results count bytes transferred, possibly fewer than the
region capacity. Nonempty read returns zero at EOF; empty read is invalidBuffer.
Empty write returns zero on a writable connection. Complete-transfer methods
return TransferResult(status, bytesTransferred), preserving partial progress on
failure; empty complete transfers succeed immediately. EOF before an exact read
finishes returns endOfStream. Success means the OS accepted bytes, not that the
remote application received or processed them.

TcpConnectionResult(status, connection?) and TcpListenerResult(status, listener?)
enforce success iff resource present, otherwise negative status with none.
Resource identity is opaque via an interface. Copies of enclosing results
preserve interface identity, not independent descriptor ownership. Explicit
close is required: GC/RC manages object memory, not external descriptors.
Close is idempotent, and closing a listener does not close accepted connections.
shutdownWrite is idempotent while open and still permits reading. Address
methods return detached snapshots and remain useful after close.

## Status values

These are portable status values, not native errno values. The unused frame-only values -2 and -4 are retired; the retained status numbers are unchanged.

| Value | NetworkStatus method |
| --- | --- |
| 0 | success |
| -1 | wouldBlock |
| -3 | closed |
| -5 | invalidBuffer |
| -6 | invalidAddress |
| -7 | invalidOptions |
| -8 | addressInUse |
| -9 | connectionRefused |
| -10 | connectionReset |
| -11 | timedOut |
| -12 | resolutionFailed |
| -13 | permissionDenied |
| -14 | unreachable |
| -15 | endOfStream |
| -16 | ioError |
| -17 | unsupported |

The initial synchronous provider delegates socket creation, resolution, connect, bind, listen, accept, options, send, receive and close to Nim standard net/nativesockets APIs. Existing Nim POSIX bindings provide poll and half-close, with monotonic deadlines, interrupted-operation retries and SIGPIPE suppression. No embedded C implementation or native socket registry is needed. Linux is the supported provider; non-Linux acquisition reports
unsupported. Address resolution and native sockaddr/error handling are platform
operations, not Eido compiler semantics.

## Testing and limitations

Run `EIDO_TEST_FILTER="Integration::TCP networking" nimble test`. The Linux
integration driver uses ephemeral localhost ports, separate processes and both
standard memory policies. It covers IPv4/IPv6, partial EOF and timeout progress,
write backpressure, options snapshots, rejection of strided buffers, half-close,
invalid options/address, address-in-use and refusal, idempotent closure and
descriptor counts after repeated acquisition/close.

Single-threaded use only. UDP, readiness APIs, thread safety, automatic resource
cleanup, TLS, common file/stream helpers and Eido-managed protocols are later
increments. No connection throughput claims have been benchmarked.
