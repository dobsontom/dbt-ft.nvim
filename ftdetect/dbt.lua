if vim.g.loaded_dbt_ft then
  return
end

vim.filetype.add({
  pattern = {
    [".*%.sql"] = function(path)
      return require("dbt-ft").detect(path)
    end,
  },
})
