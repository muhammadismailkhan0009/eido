import std/[strutils, unittest]
import backend/nim/emitter/[memory_metadata_emitter, instrumentation_emitter]
import compile_time/model

suite "Memory metadata emission":
  test "renders stable payload and type identifiers from generic metadata":
    let metadata = CompileTimeMemoryMetadata(
      types: @[
        CompileTimeTypeMetadata(
          className: "orders.Parent",
          size: 24,
          alignment: 8,
          fields: @[
            CompileTimeFieldMetadata(
              fieldName: "tag",
              offset: 0,
              containsIdentity: false
            ),
            CompileTimeFieldMetadata(
              fieldName: "child",
              offset: 16,
              containsIdentity: true
            )
          ]
        )
      ]
    )

    let generated = renderMemoryMetadata(metadata, @[])

    check "eido_class_nominal_" in generated
    check "_memory_payload_size = int64(24)" in generated
    check "_memory_alignment = int64(8)" in generated
    check "_memory_type_id = int64(0)" in generated
    check "_gc_" notin generated

  test "renders nothing for empty memory metadata":
    check renderMemoryMetadata(CompileTimeMemoryMetadata(), @[]) == ""

  test "identity slots follow canonical callable names across semantic ID renumbering":
    let metadata = CompileTimeMemoryMetadata(callables: @[
      CompileTimeCallableMetadata(kind: ctkFunction, semanticId: 1,
        sourceName: "app.main", identityValues: @[CompileTimeIdentityValue(localId: 3, sourceName: "first")]),
      CompileTimeCallableMetadata(kind: ctkMethod, semanticId: 1,
        ownerName: "app.First", sourceName: "run",
        identityValues: @[CompileTimeIdentityValue(localId: 4, sourceName: "left")]),
      CompileTimeCallableMetadata(kind: ctkMethod, semanticId: 2,
        ownerName: "app.Second", sourceName: "run",
        identityValues: @[CompileTimeIdentityValue(localId: 8, sourceName: "right")])
    ])
    check identityValuesForFunction(metadata, "app.main")[0].localId == 3
    check identityValuesForMethod(metadata, "app.First", "run")[0].localId == 4
    check identityValuesForMethod(metadata, "app.Second", "run")[0].localId == 8
    check identityValuesForMethod(metadata, "app.Missing", "run").len == 0
