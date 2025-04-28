local M = {}

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
