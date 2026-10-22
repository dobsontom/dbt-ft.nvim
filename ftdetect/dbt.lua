-- The guard is here rather than in plugin/, whose predicate every Jinja buffer's queries need.
if vim.g.loaded_dbt_ft then
  return
end
vim.g.loaded_dbt_ft = true

vim.filetype.add({
  pattern = {
    [".*%.sql"] = function(path)
      return require("dbt-ft").detect(path)
    end,
  },
})
