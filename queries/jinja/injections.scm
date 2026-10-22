; extends

; The Jinja text is SQL, and each {{ }} expression stands in for the SQL it renders, so
; `from {{ ref('x') }} where` reaches SQL as `from ref('x') where`. Without include-children
; Neovim would drop the expression's own nodes. config() renders nothing, so it stays out.
([
  (content) @injection.content
  (render_expression
    (expression) @injection.content)
]
  (#not-lua-match? @injection.content "^%s*config%s*%(")
  (#inject-dbt-sql! @injection.content)
  (#set! injection.include-children)
  (#set! injection.combined))
