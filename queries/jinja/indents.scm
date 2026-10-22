; extends

; Jinja lines keep 'autoindent', since Jinja's tree can't see the nesting of
; the language around it. The query exists so that setups enabling tree-sitter
; indents per language, such as LazyVim, do so for dbt buffers, whose lines
; then follow the SQL injection's indents.
(source) @indent.auto
