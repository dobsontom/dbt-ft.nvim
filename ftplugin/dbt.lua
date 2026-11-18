if vim.b.did_ftplugin then
  return
end

vim.cmd("runtime! ftplugin/sql[.]{vim,lua} ftplugin/sql_*.{vim,lua} ftplugin/sql/*.{vim,lua}")

vim.bo.commentstring = "{# %s #}"
-- `r` and `o` also continue a /* */ comment with ` * `, through the
-- s1:/*,mb:*,ex:*/ entry in SQL's 'comments'. That entry stays, as gq flattens
-- a starred block without it.
vim.opt_local.formatoptions:append("ro")

local dbt_ft = require("dbt-ft")
if dbt_ft.enabled("dbt_recommended_style") then
  local function positive(value)
    local number = tonumber(value)
    return number and number > 0 and number
  end
  local model = dbt_ft.buf_path(0)
  local sqlfluff = model and require("dbt-ft.sqlfluff").settings(model) or {}
  local indent = positive(sqlfluff.tab_space_size) or 4
  if sqlfluff.indent_unit == "tab" then
    -- SQLFluff's indent is then one tab, and tab_space_size its width.
    vim.bo.expandtab = false
    vim.bo.tabstop = indent
    vim.bo.shiftwidth = 0
    vim.bo.softtabstop = 0
  else
    vim.bo.expandtab = true
    vim.bo.shiftwidth = indent
    vim.bo.softtabstop = -1
  end
  -- SQLFluff takes zero or less as no limit.
  local length = positive(sqlfluff.max_line_length)
  if length then
    vim.bo.textwidth = length
  end
  vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "") .. "\n setl et< sw< sts< ts< tw<"
end

-- A lookbehind, so a match starts at the keyword rather than at a `{`, which
-- the next % would take for a brace.
local tag = [[\%({%[-+]\=\s*\)\@<=]]
local function words(...)
  return tag .. table.concat({ ... }, [[\>:]] .. tag) .. [[\>]]
end
local match_words = {
  words("if", [[\%(elif\|else\)]], "endif"),
  -- No else: sharing it with if sends % from a {% for %} to the {% else %}
  -- of an if inside the loop.
  words("for", "endfor"),
  words([[\(autoescape\|block\|call\|filter\|macro\|raw\|with\|materialization\|snapshot\|test\)]], [[end\1]]),
}
-- SQL's words include a bare \<if\>, so Jinja's go first to win on `{% if %}`.
match_words[#match_words + 1] = vim.b.match_words
vim.b.match_words = table.concat(match_words, ",")

-- Tree-sitter folds only hear of changes to the root Jinja tree, so the SQL
-- has to be parsed before they are first computed, or the model opens with
-- its Jinja folds alone.
local parser = vim.treesitter.get_parser(0, nil, { error = false })
if parser then
  parser:parse(true)
end
