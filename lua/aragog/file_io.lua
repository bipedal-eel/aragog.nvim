local parse_workspace = require "aragog.parse_workspace"

---@class file_io
---@field root_dir string
---@field store_dir string
---@field workspaces workspace[] | nil
local M = {}

---@return workspace[] | nil
local function workspaces()
  local matches = vim.fn.glob(M.root_dir .. "/.vscode/*.code-workspace", true, true)
  if #matches == 0 then
    return
  end

  local file = io.open(matches[1], "r")
  if not file then
    return
  end
  local content = file:read("a")

  return parse_workspace.vsc_folders(content)
end

function M.init()
  local data_path = vim.fn.stdpath("data") .. "/aragog.clutch"
  local dir = vim.fn.finddir(data_path)
  if dir == "" then
    vim.fn.mkdir(data_path)
  end

  M.root_dir = vim.fn.getcwd()
  M.store_dir = data_path .. "/" .. vim.fn.substitute(M.root_dir, "/", "_", "g")
  M.workspaces = workspaces()
end

---@return string | nil
function M.read_clutch()
  assert(M.store_dir, "[Aragog] dir should not be nil")
  local file = io.open(M.store_dir, "r")
  if not file then
    return
  end

  local content = file:read("a")
  file:close()
  return content
end

---@param content string content to perstist
function M.write_to_clutch(content)
  local file = io.open(M.store_dir, "w")

  if not file then
    error("[Aragog] failed to open file for writing: " .. M.store_dir)
  end

  file:write(content)

  file:close()
end

return M
