import std/unittest
import tooling/formatting_service

suite "Source formatting tooling":
  test "formats declarations control flow and expressions deterministically":
    let source =
      "function main(){var value=1;if(value<2){set value=value+1;}else{return;}}"

    check formatSource(source) == """
function main() {
    var value = 1;
    if (value < 2) {
        set value = value + 1;
    } else {
        return;
    }
}
"""

  test "keeps for clauses on one line while formatting the body":
    let source =
      "function main(){for(var i=0;i<2;set i=i+1){var x=i;}}"

    check formatSource(source) == """
function main() {
    for (var i = 0; i < 2; set i = i + 1) {
        var x = i;
    }
}
"""

  test "preserves standalone and trailing line comments":
    let source = """// entry point
function main(){// initialize
var value=1; // trailing value
// increment once
set value=value+1;
}
"""

    let formatted = formatSource(source)

    check formatted == """// entry point
function main() { // initialize
    var value = 1; // trailing value
    // increment once
    set value = value + 1;
}
"""
    check formatSource(formatted) == formatted

  test "preserves apostrophes and char literals around comments":
    let source = """function main(){
// it's a comment, not a Char
var letter='A'; // letter's value
}
"""

    check formatSource(source) == """function main() {
    // it's a comment, not a Char
    var letter = 'A'; // letter's value
}
"""

  test "preserves comment between closing brace and else":
    let source = """function main(){if(true){return;} // branch's end
else{return;}}
"""

    check formatSource(source) == """function main() {
    if (true) {
        return;
    } // branch's end
    else {
        return;
    }
}
"""

  test "preserves final comment at end of file":
    let source = "function main(){}\n// final comment"

    check formatSource(source) == """function main() {
}
// final comment
"""
