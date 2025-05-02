---@class Utils
---@field root_dir_head string
local M = {}

M.root_dir_head = vim.fn.fnamemodify(vim.fn.getcwd(), ":h")

---@param fn function
---@param ... unknown
---@return function
function M.fun(fn, ...)
  local args = table.pack(...)
  return function()
    fn(table.unpack(args))
  end
end

return M
