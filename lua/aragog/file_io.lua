---@alias vsc_folder { name: string | nil, path: string }

---@class file_io
---@field root_dir string
---@field store_dir string
---@field vsc_folders vsc_folder[] | nil
local M = {}

---@return vsc_folder[] | nil
local function vsc_workspace_folder()
  local matches = vim.fn.glob(M.root_dir .. "/.vscode/*.code-workspace", true, true)
  if #matches == 0 then
    return
  end

  local file = io.open(matches[1], "r")
  if not file then
    return
  end
  local res = file:read("a")

  return vim.json.decode(res).folders
end

function M.init()
  local data_path = vim.fn.stdpath("data") .. "/aragog.clutch"
  local dir = vim.fn.finddir(data_path)
  if dir == "" then
    vim.fn.mkdir(data_path)
  end

  M.root_dir = vim.fn.getcwd()
  M.store_dir = data_path .. "/" .. vim.fn.substitute(M.root_dir, "/", "_", "g")
  M.vsc_folders = vsc_workspace_folder()
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
