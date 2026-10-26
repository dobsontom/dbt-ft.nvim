; extends

; The Jinja text is SQL, and each {{ }} expression stands in for the SQL it
; renders, so `from {{ ref('x') }} where` reaches SQL as `from ref where`.
; Without include-children Neovim would drop the expression's own nodes.
([
  (content) @injection.content
  (render_expression
    (expression) @injection.content)
]
  (#dbt-sql? @injection.content)
  (#dbt-sql-range! @injection.content)
  (#set! injection.language "sql")
  (#set! injection.include-children)
  (#set! injection.combined))
