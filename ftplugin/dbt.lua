if vim.b.did_ftplugin then
  return
end

vim.cmd("runtime! ftplugin/sql[.]{vim,lua} ftplugin/sql_*.{vim,lua} ftplugin/sql/*.{vim,lua}")
vim.b.did_ftplugin = 1

vim.bo.commentstring = "{# %s #}"

if vim.g.loaded_matchit then
  -- A lookbehind, so a match starts at the keyword and the next % doesn't take `{` as a brace.
  local tag = [[\%({%[-+]\=\s*\)\@<=]]
  local jinja = {
    tag .. [[if\>:]] .. tag .. [[el\%(if\|se\)\>:]] .. tag .. [[endif\>]],
    tag .. [[for\>:]] .. tag .. [[else\>:]] .. tag .. [[endfor\>]],
    tag
      .. [[\(macro\|call\|filter\|block\|with\|raw\|trans\|autoescape\|snapshot\|test\|materialization\|docs\)\>:]]
      .. tag
      .. [[end\1\>]],
  }
  -- SQL's own words include a bare \<if\>, so Jinja's go first to win on a `{% if %}`.
  vim.b.match_words = table.concat(jinja, ",") .. (vim.b.match_words and "," .. vim.b.match_words or "")
end
