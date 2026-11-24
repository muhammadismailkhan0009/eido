const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

// Use the same TextMate and Oniguruma packages as the editor. Set
// EIDO_TEXTMATE_NODE_MODULES to the editor's node_modules directory, or
// install vscode-textmate and vscode-oniguruma in this extension.
const root = process.env.EIDO_TEXTMATE_NODE_MODULES;
const load = name => require(root ? path.join(root, name) : name);
const textmate = load("vscode-textmate");
const oniguruma = load("vscode-oniguruma");
const wasmPath = root
  ? path.join(root, "vscode-oniguruma/release/onig.wasm")
  : require.resolve("vscode-oniguruma/release/onig.wasm");

async function main() {
  const bytes = fs.readFileSync(wasmPath);
  await oniguruma.loadWASM(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
  const grammarPath = path.join(__dirname, "../syntaxes/eido.tmLanguage.json");
  const registry = new textmate.Registry({
    onigLib: Promise.resolve({
      createOnigScanner: patterns => new oniguruma.OnigScanner(patterns),
      createOnigString: text => new oniguruma.OnigString(text)
    }),
    loadGrammar: async scope => scope === "source.eido"
      ? textmate.parseRawGrammar(fs.readFileSync(grammarPath, "utf8"), grammarPath)
      : null
  });
  const grammar = await registry.loadGrammar("source.eido");
  for (const comment of [
    "// it's a comment", "// user's \"unclosed quote",
    "/// developer's documentation", "var value = 1; // it's a trailing comment",
    "// don't parse 'x' or function or \"string"
  ]) {
    const line = grammar.tokenizeLine(comment, textmate.INITIAL);
    const at = comment.indexOf("//");
    const commentToken = line.tokens.find(t => t.startIndex <= at && t.endIndex > at);
    assert(commentToken.scopes.includes("comment.line.double-slash.eido"), comment);
    const next = grammar.tokenizeLine("function next() returns Int { return 42; }", line.ruleStack);
    assert(next.tokens.some(t => t.scopes.includes("keyword.declaration.eido")), comment);
    assert(next.tokens.some(t => t.scopes.includes("constant.numeric.eido")), comment);
    assert(!next.tokens.some(t => t.scopes.some(s => s.startsWith("comment.") || s.startsWith("string."))), comment);
  }
  const string = grammar.tokenizeLine('var url = "https://example.test";', textmate.INITIAL);
  assert(!string.tokens.some(t => t.scopes.includes("comment.line.double-slash.eido")));
  const char = grammar.tokenizeLine("var letter = 'a';", textmate.INITIAL);
  assert(char.tokens.some(t => t.scopes.includes("constant.character.eido")));
  const config = require("../language-configuration.json");
  for (const quote of ["'", '"']) {
    assert(config.autoClosingPairs.find(p => p.open === quote).notIn.includes("comment"));
  }
  console.log("TextMate comment/quote regression checks passed");
}
main().catch(error => { console.error(error); process.exitCode = 1; });
