local M = {}

local sections = { indent_unit = "indentation", max_line_length = "core", tab_space_size = "indentation" }

local headers = {
  sqlfluff = "core",
  ["sqlfluff:indentation"] = "indentation",
  ["tool.sqlfluff.core"] = "core",
  ["tool.sqlfluff.indentation"] = "indentation",
}

-- pyproject.toml first, as SQLFluff lets it override a .sqlfluff beside it.
local configs = { "pyproject.toml", ".sqlfluff" }

---@param path string
---@param found table<string, string>
local function read(path, found)
  -- Not filereadable() first, which makes two system calls for a missing file
  -- where this makes one, and they are slow on a mount such as WSL's /mnt/c.
  local file = io.open(path)
  if not file then
    return
  end
  -- A directory opens too, and reads as nil.
  local text = file:read("*a") or ""
  file:close()
  local section
  for line in vim.gsplit(text, "\n", { plain = true }) do
    local header = line:match("^%s*%[([^%]]+)%]")
    if header then
      section = headers[header]
    elseif section then
      local key, value = line:match([[^%s*([%w_]+)%s*=%s*["']?(%-?[%w_]+)]])
      if sections[key] == section and not found[key] then
        found[key] = value
      end
    end
  end
end

---@param model string
---@return table<string, string>
function M.settings(model)
  local found, home = {}, vim.uv.os_homedir()
  for dir in vim.fs.parents(model) do
    for _, config in ipairs(configs) do
      read(vim.fs.joinpath(dir, config), found)
    end
    -- SQLFluff's own search starts at the home directory for a file under it.
    if dir == home then
      break
    end
  end
  return found
end

return M
