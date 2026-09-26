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
- no setting from existing class values before copy/ref semantics

`class_field_access_variants_test.nim` covers:

- primitive field reads
- nested class-field chains
- field access inside ordinary expressions
- direct access from fresh construction
- unknown-field rejection
- primitive-receiver rejection
- rejection of implicit alias/copy bindings from class-valued fields

`class_method_variants_test.nim` covers:

- read-only own-field access inside methods
- method parameters/results and instance calls
- zero-result method call statements
- existing locals/control flow inside method bodies
- method calls to top-level functions
- method calls through class-valued fields
- field/parameter/local/nested-local uniqueness constraints
- rejection of field mutation before `set` semantics

Field mutation, interfaces, contracts, and class-valued explicit function/method
signatures remain outside the current class slice.
