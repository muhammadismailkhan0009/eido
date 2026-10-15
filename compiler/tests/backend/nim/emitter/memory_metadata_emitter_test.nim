import std/[strutils, unittest]
import backend/nim/emitter/memory_metadata_emitter
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
