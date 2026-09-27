# Class feature coverage

`class_declaration_variants_test.nim` covers:

- field-only nominal class declarations
- zero-field classes
- primitive field types
- forward nominal field references
- rejection of unknown field types

`class_construction_variants_test.nim` covers:

- complete named construction with `Type { field = expression; }`
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

`class_method_variants_test.nim` covers true instance behavior:

- explicit `self.field` reads inside methods
- method parameters/results and explicit-instance calls
- zero-result method call statements
- existing locals/control flow inside method bodies
- method calls to top-level functions
- method calls through class-valued fields
- `set self.field = ...` for own field mutation; class relationship variants are exercised in the copy/ref catalog
- field/parameter/local/nested-local uniqueness constraints

`class_static_method_variants_test.nim` covers inferred type-associated behavior:

- self-free class functions inferred as static with no keyword
- required `Type.method(...)` call syntax and rejection of instance-call syntax
- rejection of class-call syntax for self-dependent instance methods
- static-to-static calls, static factories, and zero-result static calls
- fields do not make a method instance-bound unless the body explicitly reaches `self`
- `static function` syntax is rejected because method kind is compiler-inferred

`self_receiver_variants_test.nim` covers current-instance field/method access,
same-name top-level function separation, and invalid receiver contexts.

`class_copy_ref_variants_test.nim` covers explicit ref aliasing, detached copy,
class parameters preserving identity, copy/ref construction fields, recursive
detachment with internal sharing preservation, detached class returns, and
class relationship replacement through `set` for locals and own class fields.

Interfaces and contracts remain outside the current class slice.
