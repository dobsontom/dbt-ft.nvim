if vim.g.loaded_dbt_ft then
  return
end
vim.g.loaded_dbt_ft = true

vim.treesitter.language.register("jinja", "dbt")

-- Every Jinja filetype shares the jinja queries, so this keeps the SQL injection to dbt buffers.
vim.treesitter.query.add_directive("inject-dbt-sql!", function(match, _, source, pred, metadata)
  if type(source) ~= "number" or vim.bo[source].filetype ~= "dbt" then
    return
  end
  metadata["injection.language"] = "sql"
  -- Leave out the indent before a tag, so gc there gives {# #}, which hides the tag from Jinja,
  -- rather than SQL's --, which doesn't. The newline stays to keep the SQL either side apart.
  local id = pred[2]
  local node = match[id] and match[id][1]
  if not node then
    return
  end
  local srow, scol, erow, ecol = node:range()
  if erow > srow and ecol > 0 and not vim.api.nvim_buf_get_text(source, erow, 0, erow, ecol, {})[1]:find("%S") then
    metadata[id] = metadata[id] or {}
    metadata[id].range = { srow, scol, erow, 0 }
  end
end, { force = true })
