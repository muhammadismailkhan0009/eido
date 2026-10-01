## Protocol-neutral model for generated Eido API documentation.
## The model distinguishes source visibility from implementation origin so
## tooling can explain what consumers may use without treating backend support
## as Eido API.

type
  DocumentationVisibility* = enum
    dvPublic,
    dvInternal

  DocumentationOrigin* = enum
    doSource,
    doCompiler

  DocumentationDeclarationKind* = enum
    ddkClass,
    ddkInterface,
    ddkFunction

  DocumentationMemberKind* = enum
    dmkField,
    dmkMethod

  DocumentationMember* = object
    name*: string
    signature*: string
    documentation*: string
    kind*: DocumentationMemberKind
    isStatic*: bool
    isNative*: bool
    availability*: string

  DocumentationDeclaration* = object
    name*: string
    canonicalName*: string
    moduleName*: string
    sourcePath*: string
    signature*: string
    documentation*: string
    kind*: DocumentationDeclarationKind
    visibility*: DocumentationVisibility
    origin*: DocumentationOrigin
    visibleFrom*: seq[string]
    members*: seq[DocumentationMember]

  DocumentationModule* = object
    name*: string
    isSdk*: bool
    declarations*: seq[DocumentationDeclaration]

  DocumentationReference* = object
    projectName*: string
    modules*: seq[DocumentationModule]
    compilerProvided*: seq[DocumentationDeclaration]
