---@class file_io
---@field dir string
local M = {}

local data_path = vim.fn.stdpath("data") .. "/aragog.clutch"

function M.init()
  local dir = vim.fn.finddir(data_path)
  if dir == "" then
    vim.fn.mkdir(data_path)
  end

  M.dir = data_path .. "/" .. vim.fn.substitute(vim.fn.getcwd(), "/", "_", "g")
end

---@return string | nil
function M.read_clutch()
  P(M.dir)
  assert(M.dir, "[Aragog] dir should not be nil")
  local file = io.open(M.dir, "r")
  if not file then
    return
  end

  local content = file:read("a")
  file:close()
  return content
end

---@param content string content to perstist
function M.write_to_clutch(content)
  local file = io.open(M.dir, "w")

  if not file then
    error("[Aragog] failed to open file for writing: " .. M.dir)
  end

  file:write(content)

  file:close()
end

return M
