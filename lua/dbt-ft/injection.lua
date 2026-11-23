local M = {}

local text = vim.treesitter.get_node_text

local renders_nothing = { config = true, log = true, ["return"] = true }

---@param expression TSNode
---@param buf integer
---@return string? name with its package, when the expression is a call
local function callee(expression, buf)
  return text(expression, buf):match("^([%a_][%w_.]*)%s*%(")
end

-- SQL reads a loop's body as its only iteration, in which a block on
-- `not loop.first` or `not loop.last` renders nothing, so a separator there
-- such as `,` is left out rather than left dangling. A keyword one such as
-- `union all` stays, as leaving it out would cost it SQL's colour.
---@param content TSNode
---@param buf integer
---@return boolean
local function loop_separator(content, buf)
  local block = assert(content:parent())
  if block:type() ~= "if_block" then
    return false
  end
  local which = text(assert(block:named_child(0)), buf):match("^if%s+not%s+loop%.(%a+)%s*$")
  return (which == "first" or which == "last") and not text(content, buf):find("%a")
end

---@param node TSNode a `content` or an `expression`
---@param buf integer
---@return boolean
function M.renders_sql(node, buf)
  if node:type() == "expression" then
    local name = callee(node, buf)
    return not (name and (renders_nothing[name] or vim.startswith(name, "exceptions.")))
  end
  return not loop_separator(node, buf)
end

---@param expression TSNode
---@param buf integer
---@return Range4?
local function expression_range(expression, buf)
  local ternary = expression:named_child(1)
  local inline_if = ternary ~= nil and ternary:type() == "ternary_expression"
  if inline_if then
    -- SQL can't parse an inline if, so its first operand, an expression
    -- itself, stands in for it.
    expression = assert(expression:named_child(0))
  end
  local name = callee(expression, buf)
  if name then
    -- A call's arguments are Jinja, such as a list SQL can't parse, so SQL
    -- gets only the call's name, without its package so that in
    -- `amount_{{ x.f() }}` it joins the name before it as one identifier.
    local srow, scol = expression:start()
    local bare = name:match("[%w_]*$")
    return { srow, scol + #name - #bare, srow, scol + #name }
  elseif inline_if then
    return { expression:range() }
  end
end

---@param content TSNode
---@param buf integer
---@return Range4?
local function content_range(content, buf)
  local srow, scol, erow, ecol = content:range()
  local indent_before_tag = erow > srow
    and ecol > 0
    and not vim.api.nvim_buf_get_text(buf, erow, 0, erow, ecol, {})[1]:find("%S")
  if indent_before_tag then
    -- Left out, so gc on the tag's line gives {# #}, which hides the tag from
    -- Jinja, rather than SQL's --, which doesn't. The newline stays to keep
    -- the SQL either side apart.
    return { srow, scol, erow, 0 }
  end
end

---@param node TSNode a `content` or an `expression`
---@param buf integer
---@return Range4? range the part of the node SQL gets, when that isn't all of it
function M.range(node, buf)
  if node:type() == "expression" then
    return expression_range(node, buf)
  end
  return content_range(node, buf)
end

return M
