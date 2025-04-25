local M = {}

local data_path = vim.fn.stdpath("data") .. "/aragog.clutch"

local function init()
  local dir = vim.fn.finddir(data_path)
  if dir == "" then
    vim.fn.mkdir(data_path)
  end
end

---TODO would be cool if this would not have to be done every time but rather be const and change on DirChanged
---Gets the right clutch for given dir
---@param dir string
---@return string
local function get_filepath(dir)
  return data_path .. "/" .. vim.fn.substitute(dir, "/", "_", "g")
end

---@param dir string dir to read file from
---@return string | nil
function M.read_clutch(dir)
  assert(dir, "[Aragog] dir should not be nil")
  local file = io.open(get_filepath(dir), "r")
  if not file then
    return
  end

  local content = file:read("a")
  file:close()
  return content
end

---@param dir string dir to persist or create clutch for
---@param content string content to perstist
function M.write_to_clutch(dir, content)
  local path = get_filepath(dir)
  local file = io.open(path, "w")

  if not file then
    error("[Aragog] failed to open file for writing: " .. path)
  end

  file:write(content)

  file:close()
end

init()

return M
