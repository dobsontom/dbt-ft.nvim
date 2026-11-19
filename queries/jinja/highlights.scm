; extends

; Above the default 100, so a call's name keeps this colour rather than the
; table or column colour SQL gives it.
(function_call
  (identifier) @function.call
  (#set! priority 101))

; dbt's own functions, from
; https://docs.getdbt.com/reference/dbt-jinja-functions, above the call colour.
; #dbt? goes last, so only dbt's names look up the buffer's filetype.
(function_call
  .
  (identifier) @function.builtin
  (#any-of? @function.builtin
    "config" "debug" "doc" "env_var" "fromjson" "fromyaml" "is_incremental" "load_result"
    "local_md5" "log" "print" "ref" "return" "run_query" "set" "set_strict" "source" "statement"
    "tojson" "toyaml" "var" "zip" "zip_strict")
  (#dbt?)
  (#set! priority 102))

; dbt's context variables, as an expression's first name only, so a member such
; as `node.config.target` isn't taken for dbt's. Names also common as locals,
; such as model and schema, are left out.
(primary_expression
  .
  (identifier) @variable.builtin
  (#any-of? @variable.builtin
    "adapter" "builtins" "dbt_version" "exceptions" "execute" "flags" "graph" "invocation_id"
    "modules" "project_name" "run_started_at" "selected_resources" "target" "this" "thread_id")
  (#dbt?)
  (#set! priority 102))
