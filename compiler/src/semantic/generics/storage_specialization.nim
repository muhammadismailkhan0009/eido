## Materializes only the compiler-owned raw Storage<Byte> capability and the
## private representation bridges required by SDK Eido Storage<T> wrappers.

import ../../source/span
import ../../frontend/ast/[declarations, type_references]
import ../../types/storage

## Creates one synthetic compiler-backed method declaration.
proc storageMethod(
  span: SourceSpan,
  moduleName,
  name: string,
  parameters: seq[Parameter],
  resultRef: FunctionResultRef
): FunctionDecl =
  FunctionDecl(
    span: span,
    name: name,
    moduleName: moduleName,
    isNative: true,
    parameters: parameters,
    result: resultRef,
    requires: @[],
    ensures: @[],
    body: @[]
  )

## Builds the Int type reference used by synthetic Storage capability methods.
proc intType(span: SourceSpan): TypeRef =
  TypeRef(span: span, name: "Int", arguments: @[], isOptional: false)

## Builds one concrete Storage type reference for synthetic raw/bridge methods.
proc storageType(span: SourceSpan, name: string): TypeRef =
  TypeRef(span: span, name: name, arguments: @[], isOptional: false)

## Materializes the one compiler-provided Storage specialization: Storage<Byte>.
proc specializeRawStorageClass*(
  concreteName: string,
  elementType: TypeRef,
  moduleName: string = ""
): ClassDecl =
  let span = elementType.span
  let intRef = intType(span)
  let rawType = storageType(span, concreteName)

  proc makeMethod(
    name: string,
    parameters: seq[Parameter],
    resultRef: FunctionResultRef
  ): FunctionDecl =
    storageMethod(span, moduleName, name, parameters, resultRef)

  var methods = @[
    makeMethod(
      "allocate",
      @[Parameter(span: span, name: "allocations", typeRef: intRef)],
      FunctionResultRef(kind: frrSingle, typeRef: rawType)
    ),
    makeMethod(
      "allocateRaw",
      @[
        Parameter(span: span, name: "allocations", typeRef: intRef),
        Parameter(span: span, name: "bytesPerAllocation", typeRef: intRef)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: rawType)
    ),
    makeMethod(
      "fromAddress",
      @[
        Parameter(span: span, name: "startingAddress", typeRef: intRef),
        Parameter(span: span, name: "allocations", typeRef: intRef),
        Parameter(span: span, name: "bytesPerAllocation", typeRef: intRef)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: rawType)
    ),
    makeMethod(
      "borrowAddress",
      @[
        Parameter(span: span, name: "startingAddress", typeRef: intRef),
        Parameter(span: span, name: "allocations", typeRef: intRef),
        Parameter(span: span, name: "bytesPerAllocation", typeRef: intRef)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: rawType)
    ),
    makeMethod(
      "view",
      @[
        Parameter(span: span, name: "storage", typeRef: rawType),
        Parameter(span: span, name: "start", typeRef: intRef)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: rawType)
    ),
    makeMethod(
      "viewAt",
      @[
        Parameter(span: span, name: "storage", typeRef: rawType),
        Parameter(span: span, name: "byteOffset", typeRef: intRef)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: rawType)
    ),
    makeMethod(
      "slice",
      @[
        Parameter(span: span, name: "storage", typeRef: rawType),
        Parameter(span: span, name: "start", typeRef: intRef),
        Parameter(span: span, name: "count", typeRef: intRef)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: rawType)
    ),
    makeMethod(
      "capacity",
      @[Parameter(span: span, name: "storage", typeRef: rawType)],
      FunctionResultRef(kind: frrSingle, typeRef: intRef)
    ),
    makeMethod(
      "address",
      @[Parameter(span: span, name: "storage", typeRef: rawType)],
      FunctionResultRef(kind: frrSingle, typeRef: intRef)
    ),
    makeMethod(
      "read",
      @[
        Parameter(span: span, name: "storage", typeRef: rawType),
        Parameter(span: span, name: "index", typeRef: intRef)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: elementType)
    ),
    makeMethod(
      "write",
      @[
        Parameter(span: span, name: "storage", typeRef: rawType),
        Parameter(span: span, name: "index", typeRef: intRef),
        Parameter(span: span, name: "value", typeRef: elementType)
      ],
      FunctionResultRef(kind: frrNone)
    ),
    makeMethod(
      "release",
      @[Parameter(span: span, name: "storage", typeRef: rawType)],
      FunctionResultRef(kind: frrNone)
    ),
    makeMethod("size", @[], FunctionResultRef(kind: frrSingle, typeRef: intRef)),
    makeMethod("alignment", @[], FunctionResultRef(kind: frrSingle, typeRef: intRef))
  ]

  ClassDecl(
    span: span,
    name: concreteName,
    moduleName: moduleName,
    typeParameters: @[],
    implements: @[],
    fields: @[],
    invariants: @[],
    methods: methods
  )

## Adds compiler-private representation bridges to one SDK Eido Storage<T>
## specialization. Public Storage behavior remains in ordinary Eido methods.
proc addTypedStorageBridges*(
  source: var ClassDecl,
  elementType: TypeRef,
  rawConcreteName: string
) =
  let span = elementType.span
  let intRef = intType(span)
  let typedRef = storageType(span, source.name)
  let rawRef = storageType(span, rawConcreteName)

  source.methods.add storageMethod(
    span,
    source.moduleName,
    StorageInternalFromRaw,
    @[Parameter(span: span, name: "storage", typeRef: rawRef)],
    FunctionResultRef(kind: frrSingle, typeRef: typedRef)
  )
  source.methods.add storageMethod(
    span,
    source.moduleName,
    StorageInternalRaw,
    @[Parameter(span: span, name: "storage", typeRef: typedRef)],
    FunctionResultRef(kind: frrSingle, typeRef: rawRef)
  )
  source.methods.add storageMethod(
    span,
    source.moduleName,
    StorageInternalRead,
    @[
      Parameter(span: span, name: "storage", typeRef: typedRef),
      Parameter(span: span, name: "index", typeRef: intRef)
    ],
    FunctionResultRef(kind: frrSingle, typeRef: elementType)
  )
  source.methods.add storageMethod(
    span,
    source.moduleName,
    StorageInternalWrite,
    @[
      Parameter(span: span, name: "storage", typeRef: typedRef),
      Parameter(span: span, name: "index", typeRef: intRef),
      Parameter(span: span, name: "value", typeRef: elementType)
    ],
    FunctionResultRef(kind: frrNone)
  )
