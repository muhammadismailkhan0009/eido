# Native feature catalog

`native_function_variants_test.nim` covers top-level bodyless native declarations and execution through the bundled backend-support ABI.

`native_class_method_variants_test.nim` covers class-owned native APIs:

- bodyless `native function` members called as `Type.method(...)`
- direct execution against class-scoped backend ABI symbols
- rejection of instance-call syntax for native class methods
- no Eido wrapper body between the class API and native support

Both forms currently accept only primitive and `String` ABI values. Native class methods are static/type-associated in v0; native instance receivers and class-valued native parameters/results remain unsupported.
