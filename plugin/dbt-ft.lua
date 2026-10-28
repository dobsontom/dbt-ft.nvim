vim.treesitter.language.register("jinja", "dbt")

local renders_nothing = { "^%s*config%s*%(", "^%s*exceptions%.", "^%s*log%s*%(", "^%s*return%s*%(" }

-- SQL reads a loop's body as its only iteration, in which a block on
-- `not loop.first` or `not loop.last` renders nothing, so a separator there
-- such as `,` is left out rather than left dangling. A keyword one such as
-- `union all` stays, as leaving it out would cost it SQL's colour.
local function loop_separator(content, source)
  local block = content:parent()
  local tag = block:type() == "if_block" and block:named_child(0)
  local which = tag and vim.treesitter.get_node_text(tag, source):match("^if%s+not%s+loop%.(%a+)%s*$")
  return (which == "first" or which == "last") and not vim.treesitter.get_node_text(content, source):find("%a")
end

-- Every Jinja filetype shares the `jinja` queries, so this keeps the SQL
-- injection to dbt buffers. It's a predicate rather than a directive so that in
-- other Jinja buffers a match stops here, before any text is read.
vim.treesitter.query.add_predicate("dbt-sql?", function(match, _, source, pred)
  if type(source) ~= "number" or vim.api.nvim_get_option_value("filetype", { buf = source }) ~= "dbt" then
    return false
  end
  local node = match[pred[2]][1]
  if node:type() == "expression" then
    local text = vim.treesitter.get_node_text(node, source)
    for _, pattern in ipairs(renders_nothing) do
      if text:find(pattern) then
        return false
      end
    end
    return true
  end
  return not loop_separator(node, source)
end, { force = true })

-- A call's arguments are Jinja, such as a list SQL can't parse, so SQL gets
-- only the call's name, without its package so that in `amount_{{ x.f() }}`
-- it joins the name before it as one identifier. The indent before a tag is left out, so gc there gives
-- {# #}, which hides the tag from Jinja, rather than SQL's --, which doesn't.
-- The newline stays to keep the SQL either side apart.
vim.treesitter.query.add_directive("dbt-sql-range!", function(match, _, source, pred, metadata)
  -- Only reached after dbt-sql?, which rejects any source but a buffer.
  ---@cast source integer
  local id = pred[2]
  local node = match[id][1]
  local last = node:type() == "expression" and node:named_child(node:named_child_count() - 1)
  if last and last:type() == "ternary_expression" then
    -- SQL can't parse an inline if, so its first operand stands in for it.
    node = assert(node:named_child(0))
    metadata[id] = { range = { node:range() } }
  end
  local srow, scol, erow, ecol = node:range()
  if node:type() == "expression" then
    local callee = vim.treesitter.get_node_text(node, source):match("^([%a_][%w_.]*)%s*%(")
    if callee then
      local name = callee:match("[%w_]*$")
      metadata[id] = { range = { srow, scol + #callee - #name, srow, scol + #callee } }
    end
  elseif erow > srow and ecol > 0 and not vim.api.nvim_buf_get_text(source, erow, 0, erow, ecol, {})[1]:find("%S") then
    metadata[id] = { range = { srow, scol, erow, 0 } }
  end
end, { force = true })
