if vim.b.did_ftplugin then
  return
end

vim.cmd("runtime! ftplugin/sql[.]{vim,lua} ftplugin/sql_*.{vim,lua} ftplugin/sql/*.{vim,lua}")

vim.bo.commentstring = "{# %s #}"

local dbt_ft = require("dbt-ft")
if dbt_ft.enabled("dbt_recommended_style") then
  local model = dbt_ft.buf_path(0)
  local sqlfluff = model and require("dbt-ft.sqlfluff").settings(model) or {}
  local indent = tonumber(sqlfluff.tab_space_size)
  indent = indent and indent > 0 and indent or 4
  local tabs = sqlfluff.indent_unit == "tab"
  vim.bo.expandtab = not tabs
  -- With tabs, SQLFluff's indent is one tab and tab_space_size its width.
  vim.bo.shiftwidth = tabs and 0 or indent
  vim.bo.softtabstop = tabs and 0 or -1
  if tabs then
    vim.bo.tabstop = indent
  end
  local length = tonumber(sqlfluff.max_line_length)
  -- SQLFluff takes zero or less as no limit.
  if length and length > 0 then
    vim.bo.textwidth = length
  end
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "") .. "\n setl et< sw< sts< ts< tw<"
end

-- A lookbehind, so a match starts at the keyword rather than at a `{`, which
-- the next % would take for a brace.
local tag = [[\%({%[-+]\=\s*\)\@<=]]
local jinja = {
  tag .. [[if\>:]] .. tag .. [[el\%(if\|se\)\>:]] .. tag .. [[endif\>]],
  -- No else: sharing it with if sends % from a {% for %} to the {% else %}
  -- of an if inside the loop.
  tag .. [[for\>:]] .. tag .. [[endfor\>]],
  tag
    .. [[\(autoescape\|block\|call\|filter\|macro\|raw\|with\|materialization\|snapshot\|test\)\>:]]
    .. tag
    .. [[end\1\>]],
}
-- SQL's words include a bare \<if\>, so Jinja's go first to win on `{% if %}`.
vim.b.match_words = table.concat(jinja, ",") .. (vim.b.match_words and "," .. vim.b.match_words or "")

-- Tree-sitter folds only hear of changes to the root Jinja tree, so the SQL
-- has to be parsed before they are first computed, or the model opens with
-- its Jinja folds alone.
local parser = vim.treesitter.get_parser(0, nil, { error = false })
if parser then
  parser:parse(true)
end
