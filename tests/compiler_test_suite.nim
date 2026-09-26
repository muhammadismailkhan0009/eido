## Aggregates compiler-internal tests and language-facing feature acceptance tests.
## Example: `nimble test` runs both implementation contracts and executable Eido feature variants.

{.warning[UnusedImport]: off.}

import compiler/architecture/compiler_architecture_test
import compiler/frontend/lexer/scanner_test
import compiler/frontend/parser/expression_parser_test
import compiler/frontend/parser/function_parser_test
import compiler/frontend/parser/primitive_literal_parser_test
import compiler/semantic/analysis/local_binding_analysis_test
import compiler/semantic/analysis/function_analysis_test
import compiler/semantic/analysis/primitive_type_analysis_test
import compiler/semantic/analysis/comparison_analysis_test
import compiler/semantic/analysis/boolean_analysis_test
import compiler/backend/nim/emitter/nim_emitter_test
import compiler/pipeline/compiler_pipeline_test

import features/expression_variants_test
import features/function_variants_test
import features/primitive_variants_test
import features/variable_variants_test
