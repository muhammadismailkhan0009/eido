# Generic classes

Status: approved and implemented for the first v0 generic slice.

Eido classes may declare any number of type parameters:

```eido
class Pair<A, B> {
    A first;
    B second;
}
```

Applications provide every type argument explicitly:

```eido
Pair<String, Int>
Box<User>
Triple<String, Bool, Int>
```

Nested generic applications are legal:

```eido
Result<List<User>, Error>
ResponseBody<ApiResponse<List<User>>>
```

Construction uses the concrete type application:

```eido
var box = Box<Int> {
    value = 42;
};
```

Class-owned methods may use the owning class parameters. The method itself does
not declare a separate generic parameter list:

```eido
class Box<T> {
    T value;

    function create(T item) returns Box<T> {
        return Box<T> { value = item; };
    }
}

var box = Box<Int>.create(42);
```

## Static specialization

Generic classes are compile-time templates. Before ordinary semantic analysis,
each used application becomes an ordinary concrete nominal class.

Conceptually:

```text
Box<T> + Box<Int>
        ↓
concrete Box<Int>
        ↓
ordinary Eido class semantics
```

The semantic analyzer and HIR therefore operate on concrete classes rather than
Java-style erased generic values. Different applications such as `Box<Int>`
and `Box<String>` are distinct nominal types.

Specialization is transitive. If `Holder<T>` contains `Box<T>`, using
`Holder<Int>` also materializes `Box<Int>` when needed.

## Existing class rules still apply

Substitution does not weaken Eido class identity rules. If `T` becomes a class
type, construction, `copy`/`ref`, mutation, parameters, and detached-return
rules behave exactly as they would for that concrete class written by hand.

For example:

```eido
var box = Box<Account> {
    value = ref account;
};
```

requires `ref` because the concrete field type is `Account`.

## First-slice boundaries

Not included yet:

- generic top-level functions;
- method-local generic parameter lists such as `function map<U>(...)`;
- generic interfaces;
- bounds/constraints;
- variance or wildcards;
- generic type inference or raw generic types;
- class-owned native functions on generic classes.

Deep generic nesting is legal. For public APIs, meaningful named classes are
recommended when nesting becomes hard to read; this is a design principle, not
a type-system restriction.
