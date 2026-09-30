## Materializes compiler-owned concrete Storage<T> declarations.
## Storage remains an API surface while its implementation belongs to the toolchain/runtime.

import ../../source/span
import ../../frontend/ast/[declarations, type_references]

## Creates one ordinary synthetic native method declaration.
proc storageMethod(
  span: SourceSpan,
  name: string,
  parameters: seq[Parameter],
  resultRef: FunctionResultRef
): FunctionDecl =
  FunctionDecl(
    span: span,
    name: name,
    moduleName: "",
    isNative: true,
    parameters: parameters,
    result: resultRef,
    requires: @[],
    ensures: @[],
    body: @[]
  )

## Materializes the compiler-owned Storage<T> capability for one concrete element type.
proc specializeStorageClass*(
  concreteName: string,
  elementType: TypeRef
): ClassDecl =
  let span = elementType.span
  let intType = TypeRef(
    span: span,
    name: "Int",
    arguments: @[],
    isOptional: false
  )
  let storageType = TypeRef(
    span: span,
    name: concreteName,
    arguments: @[],
    isOptional: false
  )
  let byteStorageType = TypeRef(
    span: span,
    name: "Storage<Byte>",
    arguments: @[],
    isOptional: false
  )

  let allocateMethod = storageMethod(
    span,
    "allocate",
    @[Parameter(span: span, name: "allocations", typeRef: intType)],
    FunctionResultRef(kind: frrSingle, typeRef: storageType)
  )
  let viewMethod = storageMethod(
    span,
    "view",
    @[
      Parameter(span: span, name: "storage", typeRef: byteStorageType),
      Parameter(span: span, name: "start", typeRef: intType)
    ],
    FunctionResultRef(kind: frrSingle, typeRef: storageType)
  )
  let sliceMethod = storageMethod(
    span,
    "slice",
    @[
      Parameter(span: span, name: "storage", typeRef: storageType),
      Parameter(span: span, name: "start", typeRef: intType),
      Parameter(span: span, name: "count", typeRef: intType)
    ],
    FunctionResultRef(kind: frrSingle, typeRef: storageType)
  )
  let capacityMethod = storageMethod(
    span,
    "capacity",
    @[Parameter(span: span, name: "storage", typeRef: storageType)],
    FunctionResultRef(kind: frrSingle, typeRef: intType)
  )
  let readMethod = storageMethod(
    span,
    "read",
    @[
      Parameter(span: span, name: "storage", typeRef: storageType),
      Parameter(span: span, name: "index", typeRef: intType)
    ],
    FunctionResultRef(kind: frrSingle, typeRef: elementType)
  )
  let writeMethod = storageMethod(
    span,
    "write",
    @[
      Parameter(span: span, name: "storage", typeRef: storageType),
      Parameter(span: span, name: "index", typeRef: intType),
      Parameter(span: span, name: "value", typeRef: elementType)
    ],
    FunctionResultRef(kind: frrNone)
  )
  let releaseMethod = storageMethod(
    span,
    "release",
    @[Parameter(span: span, name: "storage", typeRef: storageType)],
    FunctionResultRef(kind: frrNone)
  )
  let sizeMethod = storageMethod(
    span,
    "size",
    @[],
    FunctionResultRef(kind: frrSingle, typeRef: intType)
  )
  let alignmentMethod = storageMethod(
    span,
    "alignment",
    @[],
    FunctionResultRef(kind: frrSingle, typeRef: intType)
  )

  var methods = @[
    allocateMethod,
    viewMethod,
    sliceMethod,
    capacityMethod,
    readMethod,
    writeMethod,
    releaseMethod,
    sizeMethod,
    alignmentMethod
  ]
  if elementType.name == "Byte":
    methods.insert(storageMethod(
      span,
      "allocateRaw",
      @[
        Parameter(span: span, name: "allocations", typeRef: intType),
        Parameter(span: span, name: "bytesPerAllocation", typeRef: intType)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: storageType)
    ), 1)
    methods.insert(storageMethod(
      span,
      "fromAddress",
      @[
        Parameter(span: span, name: "startingAddress", typeRef: intType),
        Parameter(span: span, name: "allocations", typeRef: intType),
        Parameter(span: span, name: "bytesPerAllocation", typeRef: intType)
      ],
      FunctionResultRef(kind: frrSingle, typeRef: storageType)
    ), 2)

  ClassDecl(
    span: span,
    name: concreteName,
    moduleName: "",
    typeParameters: @[],
    implements: @[],
    fields: @[],
    invariants: @[],
    methods: methods
  )
