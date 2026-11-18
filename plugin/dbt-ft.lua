vim.treesitter.language.register("jinja", "dbt")

-- Every Jinja filetype shares the `jinja` queries, so this keeps the SQL
-- injection to dbt buffers. It's a predicate rather than a directive so that in
-- other Jinja buffers a match stops here, before any text is read.
vim.treesitter.query.add_predicate("dbt-sql?", function(match, _, source, pred)
  -- Not vim.bo, which takes over twice as long, and this runs for every match.
  if type(source) ~= "number" or vim.api.nvim_get_option_value("filetype", { buf = source }) ~= "dbt" then
    return false
  end
  return require("dbt-ft.injection").renders_sql(match[pred[2]][1], source)
end, { force = true })

vim.treesitter.query.add_directive("dbt-sql-range!", function(match, _, source, pred, metadata)
  -- Only reached after dbt-sql?, which rejects any source but a buffer.
  ---@cast source integer
  local id = pred[2]
  local range = require("dbt-ft.injection").range(match[id][1], source)
  if range then
    metadata[id] = { range = range }
  end
end, { force = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("dbt-ft.yaml", {}),
  callback = function(args)
    require("dbt-ft.yaml").attach(assert(vim.lsp.get_client_by_id(args.data.client_id)), args.buf)
  end,
})
