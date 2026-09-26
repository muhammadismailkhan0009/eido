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
- no bare class-to-class reassignment before copy/ref semantics

Field access, field mutation, methods, interfaces, contracts, and class-valued
function signatures remain outside the current class slice.
