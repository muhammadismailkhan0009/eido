# Storage and device interoperability

## Agreed direction

Storage is the common memory substrate for memory policies, networking, files,
accelerators and device interaction. It is an extensible ecosystem, not a claim
that today's CPU-addressable Storage operations suffice for every device.
General capabilities such as mapping, device address spaces, ordered/volatile
access, DMA/RDMA registration and completion may be introduced when demonstrated
by real use cases. Do not conflate CPU addresses, DMA addresses or remote handles.

Use established domain vocabulary and standards. Define focused common
interfaces/contracts where providers have equivalent semantics; expose optional
or vendor-specific capabilities separately rather than forcing a lowest common
denominator. Official native APIs, Eido implementations, hybrids, custom
providers and simulators are all valid. Port available implementations only
where licensing and hardware documentation permit. Do not reimplement official
APIs unnecessarily, and do not claim a universal FFI exists today.

Keep provider, memory policy, protocol and execution strategy independent.
Support legacy interoperability and stable contracts where safe; do not
silently enable insecure legacy behavior. Allow independent optimization and
compile-time or runtime selection as appropriate. Avoid mandatory allocation,
copying or dispatch merely for abstract flexibility. Native code supplies
irreducible platform operations, not portable policy. Actual device control,
permissions and completion remain distinct from ordinary memory reads/writes.

## Networking order

The initial frame-interface and in-memory link experiment has been removed:
it is not used by the OS-managed socket API. Framework readiness takes
priority over raw packet and device development. TCP first, then concurrency and application libraries; defer UDP, TAP/TUN
and Eido-managed protocols until concrete requirements arise. A kernel TCP socket does not permit replacing its transport
implementation. See [TCP networking](tcp-networking.md).
