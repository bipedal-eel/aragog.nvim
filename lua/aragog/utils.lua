---@class Utils
local M = setmetatable({}, {
  __index = function(_, k)
    if k == "root_dir_head" then
      return vim.fn.fnamemodify(vim.fn.getcwd(), ":h")
    end
  end
})

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
