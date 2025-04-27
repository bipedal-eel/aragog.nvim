require "aragog.globals"
local file_io = require "aragog.file_io"
local AragogUi = require "aragog.ui"
local Colony = require "aragog.colony"

---@class AragogOpts
---@field debug boolean | nil

---@class Aragog
---@field colony Colony
---@field ui AragogUi
---@field opts AragogOpts
local M = {}

---TODO move to appropriate place something with persisting (merge with io)
local function persist_colony()
  local ok, res = pcall(file_io.write_to_clutch, vim.json.encode(M.colony.burrows))
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
  else
    M.change_burrow(idx)
  end
end

---@param opts AragogOpts | nil
function M.setup(opts)
  M.opts = opts or {}

  file_io.init()
  M.colony = Colony:new({
    debug = M.opts.debug,
  })
  M.ui = AragogUi:new(persist_colony, select_line_callback)
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

---@param idx integer index of burrow to go to
function M.change_burrow(idx)
  local ok, burrow = pcall(function() return M.colony.burrows and M.colony.burrows[idx] end)
  if not ok or not burrow then
    return
  end
  if (M.colony.current_burrow ~= burrow) then
    change_dir_by_burrow(burrow)
  end
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

function M.toggle_current_threads_window()
  M.ui:toggle_threads_window(M.colony.current_burrow)
end

function M.toggle_burrows_window()
  M.ui:toggle_burrows_window(M.colony)
end

-- TODO only save on VimLeavePre and hidrate on BufLeave -- gotta check if that works properly
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

vim.keymap.set("n", "<M-0>", function()
  -- basiaclly only the "pinned" ones would be good
  M.toggle_burrows_window()
end)

vim.keymap.set("n", "<M-1>", function()
  M.change_burrow(1)
end)

vim.keymap.set("n", "<M-2>", function()
  M.change_burrow(2)
end)

vim.keymap.set("n", "<M-3>", function()
  M.change_burrow(3)
end)

vim.keymap.set("n", "<M-4>", function()
  M.change_burrow(4)
end)

return M
