---@param stored boolean
Set_is_colony_stored = function(stored)
  vim.g._aragog_colony_stored = stored
end

---@return boolean
Get_is_colony_stored = function()
  return vim.g._aragog_colony_stored or false
end
