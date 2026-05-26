local M = {}

---Opens a Telescope picker for workspace navigation.
---@param workspaces workspace[]
---@param on_select fun(idx: integer)
---@return boolean success false if Telescope is not available
function M.workspace_picker(workspaces, on_select)
  local ok, _ = pcall(require, "telescope")
  if not ok then
    return false
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local entries = {}
  for i, ws in ipairs(workspaces) do
    table.insert(entries, {
      display = ws.name or ws.path,
      ordinal = ws.name or ws.path,
      path = ws.path,
      idx = i,
    })
  end

  pickers.new({}, {
    prompt_title = "Workspaces",
    finder = finders.new_table({
      results = entries,
      entry_maker = function(e)
        return {
          value = e,
          display = e.display,
          ordinal = e.ordinal,
          path = e.path,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local sel = action_state.get_selected_entry()
        if sel then
          on_select(sel.value.idx)
        end
      end)
      return true
    end,
  }):find()

  return true
end

return M
