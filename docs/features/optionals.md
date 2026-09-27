# Optional values

Eido types are definitely present by default. Appending `?` makes absence explicit:

```eido
Int?
String?
User?
Box<User?>?
```

Absence is written as `none`. Eido source does not expose wrapper operations such
as `.value`, `.get()`, or `.unwrap()`.

An optional value is consumed as its underlying type only inside the dedicated
lexical proof block:

```eido
if user exists {
    user.print();
}
```

Outside that exact block, `user` is optional again. Proofs nest by exact stable
paths:

```eido
if employee.address exists {
    if employee.address.city exists {
        Console.writeLine(employee.address.city.name);
    }
}
```

Skipping an optional ancestor is invalid; each optional relationship requires its
own proof before deeper access.

The initial proof model is deliberately lexical rather than effect-sensitive.
Ordinary mutation, aliases, and method calls do not invalidate an active proof.
Even a direct `set user = none;` does not yet invalidate the proof for the rest
of that block. A later semantic refinement may reject subsequent reads after an
obvious direct assignment to `none`, but alias/effect analysis is not required.

Optional class values retain existing Eido identity rules when present. Existing
objects still require explicit `ref` or `copy` at persistent relationship
boundaries; `none` itself carries no identity choice.

The Nim backend currently lowers `T?` to `Option[T]`, `none` to backend
absence, and proven source reads to backend unwrap operations. Those mechanics are
not part of Eido source semantics.
