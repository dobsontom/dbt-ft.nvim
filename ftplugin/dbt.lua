if vim.b.did_ftplugin then
  return
end

vim.cmd("runtime! ftplugin/sql[.]{vim,lua} ftplugin/sql_*.{vim,lua} ftplugin/sql/*.{vim,lua}")

vim.bo.commentstring = "{# %s #}"

-- A lookbehind, so a match starts at the keyword and the next % doesn't take `{` as a brace.
local tag = [[\%({%[-+]\=\s*\)\@<=]]
local jinja = {
  tag .. [[if\>:]] .. tag .. [[el\%(if\|se\)\>:]] .. tag .. [[endif\>]],
  -- No else: sharing it with if sends % from a {% for %} to the {% else %} of an if inside the loop.
  tag .. [[for\>:]] .. tag .. [[endfor\>]],
  tag
    .. [[\(autoescape\|block\|call\|filter\|macro\|raw\|with\|materialization\|snapshot\|test\)\>:]]
    .. tag
    .. [[end\1\>]],
}
-- SQL's own words include a bare \<if\>, so Jinja's go first to win on a `{% if %}`.
vim.b.match_words = table.concat(jinja, ",") .. (vim.b.match_words and "," .. vim.b.match_words or "")

-- Tree-sitter folds only hear of changes to the root Jinja tree, so the SQL has to be parsed before
-- they are first computed, or the model opens with its Jinja folds alone.
local parser = vim.treesitter.get_parser(0, nil, { error = false })
if parser then
  parser:parse(true)
end
