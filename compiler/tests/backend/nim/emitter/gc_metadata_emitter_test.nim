import std/[strutils, unittest]
import backend/nim/emitter/gc_metadata_emitter
import compile_time/model

suite "GC metadata emission":
  test "renders stable payload and trace constants from a memory plan":
    let plan = CompileTimeMemoryPlan(
      types: @[
        CompileTimeTypeLayout(
          className: "orders.Parent",
          size: 24,
          alignment: 8,
          fields: @[
            CompileTimeFieldLayout(
              fieldName: "tag",
              offset: 0,
              traced: false
            ),
            CompileTimeFieldLayout(
              fieldName: "child",
              offset: 16,
              traced: true
            )
          ]
        )
      ]
    )

    let generated = renderGcMetadata(plan)

    check "eido_class_nominal_" in generated
    check "_gc_payload_size = int64(24)" in generated
    check "_gc_alignment = int64(8)" in generated
    check "_gc_trace_count = 1" in generated
    check "_gc_trace_0_offset = int64(16)" in generated

  test "renders nothing for an empty memory plan":
    check renderGcMetadata(CompileTimeMemoryPlan()) == ""
