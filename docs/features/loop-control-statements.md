# Loop control statements

Eido supports `break;` and `continue;` inside loops.

```eido
while (condition) {
    if (shouldStop) {
        break;
    }

    if (shouldSkip) {
        continue;
    }

    ...
}
```

Both statements require a trailing semicolon.

## Break

`break;` immediately exits the nearest enclosing loop.

```eido
var count = 0;

while (count < 10) {
    set count = count + 1;

    if (count == 3) {
        break;
    }
}
```

After the break above, execution continues after the `while` with `count == 3`.

In nested loops, only the nearest enclosing loop is exited.

## Continue

`continue;` skips the remainder of the current iteration and begins the next
iteration of the nearest enclosing loop.

```eido
var count = 0;
var total = 0;

while (count < 5) {
    set count = count + 1;

    if (count == 3) {
        continue;
    }

    set total = total + count;
}
```

The addition is skipped when `count == 3`.

## Context rule

Loop control is valid through nested structured statements as long as a loop
still encloses the statement.

```eido
while (ready) {
    if (shouldStop) {
        break;
    }
}
```

Using either statement outside a loop is rejected:

```eido
function main() returns Int {
    break;      // invalid
    return 0;
}
```

`break` and `continue` do not take values or labels in the current language.
