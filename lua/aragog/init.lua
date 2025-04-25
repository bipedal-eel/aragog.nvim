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

---@param opts AragogOpts | nil
function M.setup(opts)
  M.opts = opts or {}

  file_io.init()
  M.colony = Colony:new({ debug = M.opts.debug })
  M.ui = AragogUi:new(M.goto_thread_destination)
end

---@param destThread Thread
function M.open_file_buffer(destThread)
  M.colony:open_file_buffer(destThread)
end

function M.append_buf_to_thread()
  M.colony:append_buf_to_thread()
end

---Open file or buffer of Thread[idx] in current Burrow
---@param idx integer index of destination thread in current burrow
function M.goto_thread_destination(idx)
  local thread = M.colony.current_burrow and M.colony.current_burrow.threads[idx]
  if not thread then
    return
  end

  M.open_file_buffer(thread)
end

function M.toggle_current_threads_window()
  if M.opts.debug then
    print("toggle_current_threads_window")
  end
  M.ui:toggle_threads_window(M.colony.current_burrow)
end

-- TODO do i need to do this or is VimLeavePre enough
local groupId = vim.api.nvim_create_augroup("aragog", { clear = true })
vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre" }, {
  group = groupId,
  callback = function()
    if not M.colony.current_burrow then
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

    local ok, res = pcall(file_io.write_to_clutch, vim.json.encode(M.colony.burrows))

    if not ok then
      vim.notify("error persisting colony" .. res, vim.log.levels.ERROR)
      return
    end
    Set_is_colony_stored(true)
  end,
})

vim.api.nvim_create_autocmd("DirChanged", {
  group = groupId,
  callback = function(args)
    if args.match == "global" then
      M.colony:on_change_dir(vim.fn.getcwd())
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
