vim.filetype.add({
  pattern = {
    [".*%.sql"] = function(path)
      return require("dbt-ft").detect(path)
    end,
  },
})
