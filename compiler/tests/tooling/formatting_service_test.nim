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
