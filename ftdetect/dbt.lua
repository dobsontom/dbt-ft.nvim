-- The guard is here rather than in plugin/, because the `jinja` queries need
-- plugin/'s predicate in every Jinja buffer.
if vim.g.loaded_dbt_ft then
  return
end
vim.g.loaded_dbt_ft = 1

vim.filetype.add({
  pattern = {
    [".*%.sql"] = function(path)
      return require("dbt-ft").detect(path)
    end,
  },
})
