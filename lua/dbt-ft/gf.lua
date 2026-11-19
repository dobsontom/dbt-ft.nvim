local M = {}

---@param item string
---@return string
local function unquote(item)
  return (vim.trim(item):gsub("^(['\"])(.*)%1$", "%2"))
end

---@param root string
---@return string[]
local function model_paths(root)
  local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(root, "dbt_project.yml"))
  local paths, in_list = {}, false
  for _, line in ipairs(ok and lines or {}) do
    line = line:gsub("^#.*", ""):gsub("%s#.*", "")
    local value = line:match("^model%-paths:%s*(.-)%s*$")
    if value == "" then
      in_list = true
    elseif value then
      for item in value:gsub("^%[(.*)%]$", "%1"):gmatch("[^,]+") do
        paths[#paths + 1] = unquote(item)
      end
      break
    elseif in_list then
      local item = line:match("^%s+%-%s*(.-)%s*$")
      if item then
        paths[#paths + 1] = unquote(item)
      elseif line:match("^%S") then
        break
      end
    end
  end
  return #paths > 0 and paths or { "models" }
end

---@param root string
---@return string
function M.path(root)
  local dirs = model_paths(root)
  dirs[#dirs + 1] = "dbt_packages/*/models"
  for i, dir in ipairs(dirs) do
    dirs[i] = vim.fn.escape(vim.fs.joinpath(root, dir), "\\ ,") .. "/**"
  end
  return table.concat(dirs, ",")
end

---@return string
function M.includeexpr()
  local line, col = vim.api.nvim_get_current_line(), vim.fn.col(".")
  for from, args, to in line:gmatch("()%f[%w_]ref%s*(%b())()") do
    if from <= col and col < to then
      local _, model = args:match(".*[(,]%s*(['\"])(.-)%1")
      return model or vim.v.fname
    end
  end
  return vim.v.fname
end

return M
