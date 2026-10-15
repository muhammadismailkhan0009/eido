## Defines parsed and resolved module architecture records.
## module.yaml is a separate declarative architecture layer and never changes Eido source vocabulary.

type
  ModuleChildManifest* = object
    name*: string
    path*: string

  ModuleProvideManifest* = object
    contract*: string
    by*: string

  ModulePolicySource* = object
    entry*: string
    path*: string
    text*: string

  ModuleManifest* = object
    name*: string
    sources*: seq[string]
    children*: seq[ModuleChildManifest]
    dependencies*: seq[string]
    exports*: seq[string]
    provides*: seq[ModuleProvideManifest]
    adopts*: seq[string]
    policySources*: seq[string]

  ModuleProvision* = object
    contract*: string
    providerModule*: string

  ModuleSpec* = object
    name*: string
    canonicalName*: string
    parentName*: string
    manifestPath*: string
    directory*: string
    sourcePaths*: seq[string]
    children*: seq[string]
    dependencies*: seq[string]
    exports*: seq[string]
    provides*: seq[ModuleProvision]
    adopts*: seq[string]
    policySources*: seq[ModulePolicySource]
