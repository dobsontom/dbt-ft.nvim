-- Every Jinja filetype shares the `jinja` queries, so the predicates below keep
-- dbt-ft.nvim's additions to dbt buffers.
local function in_dbt(source)
  -- Not vim.bo, which takes over twice as long, and this runs for every match.
  return type(source) == "number" and vim.api.nvim_get_option_value("filetype", { buf = source }) == "dbt"
end

-- A predicate rather than a directive so that in other Jinja buffers a match
-- stops here, before any text is read.
vim.treesitter.query.add_predicate("dbt-sql?", function(match, _, source, pred)
  if not in_dbt(source) then
    return false
  end
  ---@cast source integer
  return require("dbt-ft.injection").renders_sql(match[pred[2]][1], source)
end, { force = true })

vim.treesitter.query.add_predicate("dbt?", function(_, _, source)
  return in_dbt(source)
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

-- Below the handlers, which the `jinja` queries call even with the plugin off.
-- Only the user sets the flag: this file and ftdetect/ are both safe to run
-- twice, so neither needs a load guard, and if either set it, the other would
-- read it as turned off.
if vim.g.loaded_dbt_ft then
  return
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("dbt-ft.dbtpal", {}),
  pattern = "sql",
  callback = function(args)
    -- Looked for here, not at load, as dbtpal may load after this file.
    if vim.fn.exists("#dbtPal#BufRead") == 0 then
      return
    end
    local dbt_ft = require("dbt-ft")
    local path = dbt_ft.buf_path(args.buf)
    if path and dbt_ft.detect(path) then
      vim.bo[args.buf].filetype = "dbt"
    end
  end,
})

vim.treesitter.language.register("jinja", "dbt")

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("dbt-ft.yaml", {}),
  callback = function(args)
    require("dbt-ft.yaml").attach(assert(vim.lsp.get_client_by_id(args.data.client_id)), args.buf)
  end,
})
