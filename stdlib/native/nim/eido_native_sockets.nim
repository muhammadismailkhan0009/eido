## Thin adapter from Eido's primitive socket ABI to Nim's standard networking APIs.
## Eido owns descriptor lifetime, options and complete-transfer orchestration.
when defined(linux) and not defined(nimscript):
  import std/[net, nativesockets, os, monotimes, times, options]
  import std/posix as posix

  const
    Closed = -3'i64
    InvalidBuffer = -5'i64
    InvalidAddress = -6'i64
    InvalidOptions = -7'i64
    TimedOut = -11'i64
    ResolutionFailed = -12'i64
    IoError = -16'i64

  ## Translate OS errors to the portable NetworkStatus values.
  proc status(code: OSErrorCode): int64 =
    case cint(code)
    of posix.EAGAIN: -1
    of posix.EBADF, posix.ENOTSOCK: Closed
    of posix.EADDRNOTAVAIL, posix.EAFNOSUPPORT: InvalidAddress
    of posix.EADDRINUSE: -8
    of posix.ECONNREFUSED: -9
    of posix.ECONNRESET, posix.EPIPE, posix.ECONNABORTED: -10
    of posix.ETIMEDOUT: TimedOut
    of posix.EACCES, posix.EPERM: -13
    of posix.ENETUNREACH, posix.EHOSTUNREACH, posix.ENETDOWN: -14
    else: IoError

  ## Convert a remaining monotonic duration into a bounded poll timeout.
  proc remaining(started: MonoTime, timeoutMs: int64): cint =
    if timeoutMs == 0: return -1
    let elapsed = (getMonoTime() - started).inMilliseconds
    cint(min(int64(high(cint)), max(0'i64, timeoutMs - elapsed)))

  ## Nim's POSIX readiness API fills the gap in net's pointer-based I/O timeouts.
  ## Use poll rather than select to support descriptors above FD_SETSIZE.
  proc waitReady(fd: SocketHandle, writing: bool, started: MonoTime, timeoutMs: int64): int64 =
    var event = posix.TPollfd(fd: cint(fd),
      events: if writing: posix.POLLOUT else: posix.POLLIN)
    while true:
      let delay = remaining(started, timeoutMs)
      if delay == 0: return TimedOut
      let ready = posix.poll(addr event, posix.Tnfds(1), delay)
      if ready > 0:
        return if (event.revents and posix.POLLNVAL) != 0: Closed else: 0'i64
      if ready < 0:
        let error = osLastError()
        if cint(error) != posix.EINTR: return status(error)

  ## Resolve with Nim, then use its native socket handle operations for each address.
  ## The shared deadline starts after DNS; each failed candidate is closed.
  proc openSocket(host: string, port, timeoutMs, backlog: int64, listening: bool): int64 =
    if '\0' in host or port < 0 or port > 65535 or (not listening and (host.len == 0 or port == 0)):
      return InvalidAddress
    if timeoutMs < 0 or (listening and (backlog <= 0 or backlog > high(cint).int64)):
      return InvalidOptions
    let address = if listening and host.len == 0: "0.0.0.0" else: host
    var resolved: ptr nativesockets.AddrInfo
    try:
      resolved = nativesockets.getAddrInfo(address, Port(port), nativesockets.AF_UNSPEC)
    except OSError:
      return ResolutionFailed
    defer: nativesockets.freeAddrInfo(resolved)
    let started = getMonoTime()
    result = IoError
    var candidate = resolved
    while candidate != nil:
      let current = candidate
      candidate = candidate.ai_next
      if remaining(started, timeoutMs) == 0: return TimedOut
      let family = nativesockets.toKnownDomain(current.ai_family)
      if family.isNone: continue
      var socket: net.Socket
      var keep = false
      try:
        # Unbuffered: the supplied Storage is already the transfer buffer.
        socket = net.newSocket(family.get, buffered = false, inheritable = false)
        let fd = socket.getFd()
        nativesockets.setBlocking(fd, false)
        if listening:
          socket.setSockOpt(net.OptReuseAddr, true)
          if nativesockets.bindAddr(fd, current.ai_addr, current.ai_addrlen.SockLen) != 0:
            result = status(osLastError())
            continue
          socket.listen(cint(backlog))
        else:
          # The native Nim connect overload accepts the already-resolved address
          # (including IPv6 scope), avoiding a second DNS lookup.
          if nativesockets.connect(fd, current.ai_addr, current.ai_addrlen.SockLen) != 0:
            let error = osLastError()
            if cint(error) notin [posix.EINPROGRESS, posix.EALREADY, posix.EINTR]:
              result = status(error)
              continue
            result = waitReady(fd, true, started, timeoutMs)
            if result == TimedOut: return
            if result < 0: continue
            let pending = nativesockets.getSockOptInt(fd, nativesockets.SOL_SOCKET, nativesockets.SO_ERROR)
            if pending != 0:
              result = status(OSErrorCode(pending))
              continue
        # net.Socket is an explicit-close wrapper; ownership passes to Eido.
        keep = true
        return int64(fd)
      except OSError as error:
        result = status(OSErrorCode(error.errorCode))
      finally:
        if socket != nil and not keep: socket.close()

  ## One partial direct transfer, with no temporary byte buffer.
  proc transfer(descriptor, address, count, timeoutMs: int64, sending: bool): int64 =
    if count < 0 or count > high(int).int64 or (count > 0 and address == 0):
      return InvalidBuffer
    if count == 0: return 0
    let fd = SocketHandle(descriptor)
    let data = cast[pointer](cast[uint](address))
    let started = getMonoTime()
    while true:
      let moved = if sending:
        nativesockets.send(fd, data, int(count), posix.MSG_NOSIGNAL)
      else:
        nativesockets.recv(fd, data, int(count), 0)
      if moved >= 0: return int64(moved)
      let error = osLastError()
      if cint(error) == posix.EINTR:
        if remaining(started, timeoutMs) == 0: return TimedOut
        continue
      if cint(error) notin [posix.EAGAIN, posix.EWOULDBLOCK]: return status(error)
      let ready = waitReady(fd, sending, started, timeoutMs)
      if ready < 0: return ready

  ## Query numeric endpoints through Nim's standard socket address API.
  proc endpoint(descriptor: int64, remote: bool): tuple[host: string, port: Port] =
    let fd = SocketHandle(descriptor)
    let domain = nativesockets.getSockDomain(fd)
    if remote: nativesockets.getPeerAddr(fd, domain)
    else: nativesockets.getLocalAddr(fd, domain)

## Resolve and establish one TCP connection.
proc eido_native_method_NativeSockets_connect*(host: string, port, timeoutMs: int64): int64 =
  when defined(linux) and not defined(nimscript):
    openSocket(host, port, timeoutMs, 0, false)
  else: -17

## Bind one resolved local endpoint and listen.
proc eido_native_method_NativeSockets_listen*(host: string, port, backlog: int64): int64 =
  when defined(linux) and not defined(nimscript):
    openSocket(host, port, 0, backlog, true)
  else: -17

## Accept one non-inheritable socket using Nim's native socket API.
proc eido_native_method_NativeSockets_accept*(descriptor, timeoutMs: int64): int64 =
  when defined(linux) and not defined(nimscript):
    let started = getMonoTime()
    let fd = SocketHandle(descriptor)
    while true:
      let (client, _) = nativesockets.accept(fd, inheritable = false)
      if client != nativesockets.osInvalidSocket:
        try:
          nativesockets.setBlocking(client, false)
          return int64(client)
        except OSError as error:
          nativesockets.close(client)
          return status(OSErrorCode(error.errorCode))
      let error = osLastError()
      if cint(error) == posix.EINTR:
        if remaining(started, timeoutMs) == 0: return TimedOut
        continue
      if cint(error) notin [posix.EAGAIN, posix.EWOULDBLOCK]: return status(error)
      let ready = waitReady(fd, false, started, timeoutMs)
      if ready < 0: return ready
  else: -17

## Apply established connection options.
proc eido_native_method_NativeSockets_configure*(descriptor: int64, noDelay, keepAlive: bool): int64 =
  when defined(linux) and not defined(nimscript):
    let fd = SocketHandle(descriptor)
    try:
      nativesockets.setSockOptInt(fd, posix.IPPROTO_TCP, posix.TCP_NODELAY, int(noDelay))
      nativesockets.setSockOptInt(fd, nativesockets.SOL_SOCKET, nativesockets.SO_KEEPALIVE, int(keepAlive))
      0
    except OSError as error: status(OSErrorCode(error.errorCode))
  else: -17

## Receive into caller-owned Storage.
proc eido_native_method_NativeSockets_receive*(descriptor, address, count, timeoutMs: int64): int64 =
  when defined(linux) and not defined(nimscript):
    transfer(descriptor, address, count, timeoutMs, false)
  else: -17

## Send from caller-owned Storage.
proc eido_native_method_NativeSockets_send*(descriptor, address, count, timeoutMs: int64): int64 =
  when defined(linux) and not defined(nimscript):
    transfer(descriptor, address, count, timeoutMs, true)
  else: -17

## Return the numeric endpoint host.
proc eido_native_method_NativeSockets_host*(descriptor: int64, remote: bool): string =
  when defined(linux) and not defined(nimscript):
    try: return endpoint(descriptor, remote).host
    except CatchableError: discard
  ""

## Return the endpoint port or a portable error.
proc eido_native_method_NativeSockets_port*(descriptor: int64, remote: bool): int64 =
  when defined(linux) and not defined(nimscript):
    try: int64(uint16(endpoint(descriptor, remote).port))
    except OSError as error: status(OSErrorCode(error.errorCode))
    except IOError: IoError
  else: -17

## Nim has no portable half-close method; use its existing POSIX binding.
proc eido_native_method_NativeSockets_shutdownWrite*(descriptor: int64): int64 =
  when defined(linux) and not defined(nimscript):
    if posix.shutdown(SocketHandle(descriptor), posix.SHUT_WR) == 0: 0'i64
    else: status(osLastError())
  else: -17

## Explicit closure through Nim's native socket API.
proc eido_native_method_NativeSockets_close*(descriptor: int64) =
  when defined(linux) and not defined(nimscript):
    nativesockets.close(SocketHandle(descriptor))
