local utils = require "aragog.utils"

---TODO why is this global
---@param stored boolean
Set_is_colony_stored = function(stored)
  vim.g._aragog_colony_stored = stored
end

---@return boolean
Get_is_colony_stored = function()
  return vim.g._aragog_colony_stored or false
end

---@param dir string
---@param name string | nil name of the workspace // TODO this will only make sense when vs_workspaces have been implementet
Set_current_burrow_dir = function(dir, name)
  local current_burrow = name or
  string.gsub(vim.fn.fnameescape(vim.fn.fnamemodify(dir, ":p:h")), utils.root_dir_head, "")
  vim.g.aragog_current_burrow = current_burrow
end
