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

---@param opts AragogOpts | nil
function M.setup(opts)
  M.opts = opts or {}

  file_io.init()
  M.colony = Colony:new({
    debug = M.opts.debug,
  })
  M.ui = AragogUi:new(M.goto_thread_destination)
end

---TODO what was i thinking... should this be public; not in this state, would require additional thread_builder to be public
---@param destThread Thread
function M.open_thread(destThread)
  M.colony:open_thread(destThread)
end

function M.add_file()
  M.colony:append_buf_to_thread()

  persist_colony()
end

---Open file or buffer of Thread[idx] in current Burrow
---@param idx integer index of destination thread in current burrow
function M.goto_thread_destination(idx)
  local thread = M.colony.current_burrow and M.colony.current_burrow.threads[idx]
  if not thread then
    return
  end

  M.colony:open_thread(thread)
end

function M.toggle_current_threads_window()
  vim.notify("toggle_current_threads_window", vim.log.levels.DEBUG)
  M.ui:toggle_threads_window(M.colony.current_burrow)
end

-- TODO only save on VimLeavePre and hidrate on BufLeave -- gotta check if that works properly
local groupId = vim.api.nvim_create_augroup("aragog", { clear = true })
vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre" }, {
  group = groupId,
  callback = function(args)
    if not M.colony.current_burrow or not M.colony.current_thread or M.colony.current_thread.bufnr ~= args.buf then
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

vim.keymap.set("n", "<M-1>", function()
  if #M.colony.burrows > 0 then
    vim.fn.chdir(M.colony.burrows[1].dir)
  end
end)

vim.keymap.set("n", "<M-2>", function()
  if #M.colony.burrows > 1 then
    vim.fn.chdir(M.colony.burrows[2].dir)
  end
end)

vim.keymap.set("n", "<M-3>", function()
  if #M.colony.burrows > 2 then
    vim.fn.chdir(M.colony.burrows[3].dir)
  end
end)

vim.keymap.set("n", "<M-4>", function()
  if #M.colony.burrows > 3 then
    vim.fn.chdir(M.colony.burrows[4].dir)
  end
end)

return M
