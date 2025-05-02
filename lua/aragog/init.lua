require "aragog.globals"
local utils = require "aragog.utils"
local clutch = require "aragog.clutch"
local AragogUi = require "aragog.ui"
local Colony = require "aragog.colony"

---@class AragogOpts
---@field vsc_workspace_dir string | nil
---@field debug boolean | nil

---@class Aragog
---@field colony Colony
---@field ui AragogUi
---@field opts AragogOpts
local M = {}

---TODO move to appropriate place something with persisting (merge with io)
local function persist_colony()
  local ok, res = pcall(clutch.write_to_clutch, vim.json.encode(M.colony.burrows))
  if not ok then
    vim.notify("error persisting colony" .. res, vim.log.levels.ERROR)
    return
  end
  Set_is_colony_stored(true)
end

---@param type ui_type
---@param idx integer index of destination thread in current burrow
local function select_line_callback(type, idx)
  if type == "threads" then
    M.goto_thread_destination(idx)
  elseif type == "burrows" then
    M.switch_burrow(idx)
  else
    M.switch_workspace(idx)
  end
end

---@param opts AragogOpts | nil
function M.setup(opts)
  M.opts = opts or {}
  M.opts.vsc_workspace_dir = M.opts.vsc_workspace_dir or "./.vscode"

  utils.root_dir_head = vim.fn.fnamemodify(vim.fn.getcwd(), ":h")
  clutch.init()
  M.colony = Colony:new({
    debug = M.opts.debug,
  })
  M.ui = AragogUi:new(clutch.workspaces, M.opts.vsc_workspace_dir, persist_colony, select_line_callback)
end

---@param destBurrow Burrow
local function change_dir_by_burrow(destBurrow)
  M.colony:on_dir_changed_pre()
  vim.fn.chdir(destBurrow.dir)
end

function M.add_file()
  M.colony:append_buf_to_thread()

  persist_colony()
end

---Open file or buffer of Thread[idx] in current Burrow
---@param idx integer index of destination thread in current burrow
function M.goto_thread_destination(idx)
  local ok, thread = pcall(function() return M.colony.current_burrow.threads[idx] end)
  if not ok or not thread then
    return
  end

  M.colony:open_thread(thread)
end

---@param idx integer index of burrow to go to
function M.switch_burrow(idx)
  local ok, burrow = pcall(function() return M.colony.burrows and M.colony.burrows[idx] end)
  if not ok or not burrow then
    return
  end
  if (M.colony.current_burrow ~= burrow) then
    change_dir_by_burrow(burrow)
  end
end

function M.switch_workspace(idx)
  if M.ui.workspaces[idx].idx then
    M.switch_burrow(M.ui.workspaces[idx].idx)
  else
    change_dir_by_burrow({ dir = M.ui.workspaces[idx].path })
  end
end

function M.root_burrow()
  change_dir_by_burrow({ dir = clutch.root_dir })
end

function M.toggle_current_threads_window()
  M.ui:toggle_threads(M.colony.current_burrow)
end

function M.toggle_burrows_window()
  M.ui:toggle_burrows(M.colony)
end

function M.toggle_workspace_window()
  if not M.ui.workspaces then
    return
  end
  M.colony.burrows = M.ui:toggle_workspace(M.ui.workspaces, M.colony.burrows)
end

local groupId = vim.api.nvim_create_augroup("aragog", { clear = true })
vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre" }, {
  group = groupId,
  callback = function(args)
    if not M.colony.current_burrow or not M.colony.current_thread or M.colony.current_thread.buf ~= args.buf then
      return
    end
    M.colony:hidrate_current_thread()

    if Get_is_colony_stored() then
      print("not saving")
      return
    end
    if M.opts.debug then
      print("going to save")
    end

    persist_colony()
  end,
})

vim.api.nvim_create_autocmd("DirChanged", {
  group = groupId,
  callback = function(args)
    if args.match == "global" then
      M.colony:on_dir_changed(args.file)
    end
  end
})

return M
