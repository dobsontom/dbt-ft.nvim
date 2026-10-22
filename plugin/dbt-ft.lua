vim.treesitter.language.register("jinja", "dbt")

local renders_nothing = { "^%s*config%s*%(", "^%s*exceptions%.", "^%s*log%s*%(", "^%s*return%s*%(" }

-- Every Jinja filetype shares the `jinja` queries, so this keeps the SQL
-- injection to dbt buffers. It's a predicate rather than a directive so that in
-- other Jinja buffers a match stops here, before any text is read.
vim.treesitter.query.add_predicate("dbt-sql?", function(match, _, source, pred)
  if type(source) ~= "number" or vim.api.nvim_get_option_value("filetype", { buf = source }) ~= "dbt" then
    return false
  end
  local node = match[pred[2]][1]
  if node:type() ~= "expression" then
    return true
  end
  local text = vim.treesitter.get_node_text(node, source)
  for _, pattern in ipairs(renders_nothing) do
    if text:find(pattern) then
      return false
    end
  end
  return true
end, { force = true })

-- Leave out the indent before a tag, so gc there gives {# #}, which hides the
-- tag from Jinja, rather than SQL's --, which doesn't. The newline stays to
-- keep the SQL either side apart.
vim.treesitter.query.add_directive("dbt-trim-indent!", function(match, _, source, pred, metadata)
  -- Only reached after dbt-sql?, which rejects any source but a buffer.
  ---@cast source integer
  local id = pred[2]
  local srow, scol, erow, ecol = match[id][1]:range()
  if erow > srow and ecol > 0 and not vim.api.nvim_buf_get_text(source, erow, 0, erow, ecol, {})[1]:find("%S") then
    metadata[id] = metadata[id] or {}
    metadata[id].range = { srow, scol, erow, 0 }
  end
end, { force = true })
