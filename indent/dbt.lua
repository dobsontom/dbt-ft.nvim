if vim.b.did_indent then
  return
end

vim.cmd("runtime! indent/sql[.]{vim,lua}")
