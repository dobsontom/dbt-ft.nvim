; extends

; The Jinja text is SQL, and each {{ }} expression stands in for the SQL it
; renders. Without include-children Neovim would leave out its children's text.
; SQL reads an {% if %} as its first branch, or an is_incremental() model's
; {% else %} would give it a second where.
([
  (content) @injection.content
  (render_expression
    (expression) @injection.content)
]
  (#dbt-sql? @injection.content)
  (#not-has-ancestor? @injection.content elif_block else_block)
  (#dbt-sql-range! @injection.content)
  (#set! injection.language "sql")
  (#set! injection.include-children)
  (#set! injection.combined))

; The other branches, a for loop's {% else %} included, each get their own
; tree, as a single tree spanning every line between them would take over
; those lines' indents and folds.
((content) @injection.content
  (#dbt-sql? @injection.content)
  (#has-ancestor? @injection.content elif_block else_block)
  (#dbt-sql-range! @injection.content)
  (#set! injection.language "sql"))
