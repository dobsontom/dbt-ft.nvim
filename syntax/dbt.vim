" Only seen when tree-sitter isn't highlighting the buffer: SQL's syntax with
" Jinja's tags on top.
if exists("b:current_syntax")
  finish
endif

runtime! syntax/sql.vim
unlet! b:current_syntax

syntax region dbtJinjaComment start="{#" end="#}" containedin=ALL keepend
syntax region dbtJinjaStatement start="{%" end="%}" containedin=ALL keepend
syntax region dbtJinjaExpression start="{{" end="}}" containedin=ALL keepend

highlight default link dbtJinjaComment Comment
highlight default link dbtJinjaStatement PreProc
highlight default link dbtJinjaExpression PreProc

let b:current_syntax = "dbt"
