## Names compiler-internal Eido GC runtime declarations without exposing them as
## ordinary language/runtime APIs.

import std/strutils

const
  ManagedGcRuntimeClassName* = "ManagedGcRuntime"
  ManagedGcNativeClassName* = "ManagedGcNative"

## Returns the source-local portion of one canonical nominal name.
proc managedGcLocalName(name: string): string =
  let separator = name.rfind('.')
  if separator < 0: name else: name[separator + 1 .. ^1]

## Reports whether one nominal is the hidden Eido GC policy/orchestration class.
proc isManagedGcRuntimeClassName*(name: string): bool =
  managedGcLocalName(name) == ManagedGcRuntimeClassName

## Reports whether one nominal is the hidden minimal native GC bridge.
proc isManagedGcNativeClassName*(name: string): bool =
  managedGcLocalName(name) == ManagedGcNativeClassName

## Reports whether one nominal belongs to compiler-internal managed-GC support.
proc isManagedGcInternalClassName*(name: string): bool =
  isManagedGcRuntimeClassName(name) or isManagedGcNativeClassName(name)
