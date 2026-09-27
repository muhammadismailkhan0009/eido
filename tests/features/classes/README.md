# Class feature coverage

`class_declaration_variants_test.nim` covers:

- field-only nominal class declarations
- zero-field classes
- primitive field types
- forward nominal field references
- rejection of unknown field types

`class_construction_variants_test.nim` covers:

- complete named construction with `Type { field: expression; }`
- order-independent field initialization
- nested construction
- zero-field construction
- required/exactly-once fields
- unknown/duplicate/missing-field rejection
- initializer type checking
- no implicit field-to-field initializer visibility
- no implicit class equality
- rejection of bare existing-class rebinding when copy/ref intent is absent

`class_field_access_variants_test.nim` covers:

- primitive field reads
- nested class-field chains
- field access inside ordinary expressions
- direct access from fresh construction
- unknown-field rejection
- primitive-receiver rejection
- rejection of implicit alias/copy bindings from class-valued fields

`class_method_variants_test.nim` covers:

- explicit `self.field` reads inside methods
- method parameters/results and explicit-instance calls
- zero-result method call statements
- existing locals/control flow inside method bodies
- method calls to top-level functions
- method calls through class-valued fields
- `set self.field = ...` for own primitive field mutation
- field/parameter/local/nested-local uniqueness constraints

`self_receiver_variants_test.nim` covers current-instance field/method access,
same-name top-level function separation, and invalid receiver contexts.

`class_copy_ref_variants_test.nim` covers explicit ref aliasing, detached copy,
class parameters preserving identity, copy/ref construction fields, recursive
detachment with internal sharing preservation, and detached class returns.

Interfaces, contracts, and class-valued field mutation through `set` remain
outside the current class slice.
