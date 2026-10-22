if vim.g.loaded_dbt_ft then
  return
end
vim.g.loaded_dbt_ft = true

vim.treesitter.language.register("jinja", "dbt")

-- Every Jinja filetype shares the jinja queries, so this keeps the SQL injection to dbt buffers.
vim.treesitter.query.add_directive("inject-dbt-sql!", function(_, _, source, _, metadata)
  if type(source) == "number" and vim.bo[source].filetype == "dbt" then
    metadata["injection.language"] = "sql"
  end
end, { force = true })
