; extends

; The Jinja text is SQL, and each {{ }} expression stands in for the SQL it
; renders. Without include-children Neovim would leave out its children's text.
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
