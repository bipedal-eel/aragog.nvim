---@class AragogUiOpts
---@field debug boolean | nil

---@alias Select_line_callbak fun(line_index: integer)

---@class AragogUi
---@field win integer | nil
---@field buf integer | nil
---@field select_line_callbak Select_line_callbak
---@field opts AragogUiOpts
local Ui = {}
Ui.__index = Ui

---@param select_line_callbak Select_line_callbak
---@param opts AragogUiOpts | nil
function Ui:new(select_line_callbak, opts)
  local obj = setmetatable({
    select_line_callbak = select_line_callbak,
    opts = opts or {},
  }, self)
  return obj
end

---@type function
---@param burrow Burrow
---@param paths string[]
---@param new_paths string[]
---@return Thread[]
local function map_paths_to_threads(burrow, paths, new_paths)
  ---@type Thread[]
  local new_threads = {}
  for i, new_path in pairs(new_paths) do
    if new_path == paths[i] then
      table.insert(new_threads, burrow.threads[i])
      goto continue
    end

    local index = vim.fn.indexof(paths, string.format("v:val == '%s'", new_paths[i]))
    if index ~= -1 then
      table.insert(new_threads, burrow.threads[index + 1])
    else
      table.insert(new_threads, { path = new_path })
    end
    ::continue::
  end

  return new_threads
end

---@param self AragogUi
local function set_closers(self)
  assert(self.win, "win must not be nil")
  assert(self.buf, "buf must not be nil")

  local close_win = function() self:close_win() end
  vim.api.nvim_buf_set_keymap(self.buf, "n", "<ESC>", "", { callback = close_win, desc = "close window" })
  vim.api.nvim_buf_set_keymap(self.buf, "n", "q", "", { callback = close_win, desc = "close window" })
  vim.api.nvim_buf_set_keymap(self.buf, "n", "<CR>", "", {
    callback = function()
      -- TODO this does not work
      self.select_line_callbak(vim.api.nvim_win_get_position(self.win)[1])
    end
  })
end

function Ui:close_win()
  vim.api.nvim_win_close(self.win, true)
  self.buf = nil
  self.win = nil
end

---@param burrow Burrow | nil
function Ui:toggle_threads_window(burrow)
  if self.win then
    self:close_win()

    return
  end

  if not burrow then
    return
  end

  self.buf = vim.api.nvim_create_buf(false, true)
  local temp_width = math.floor(vim.o.columns * 0.6)
  local temp_height = 6

  self.win = vim.api.nvim_open_win(self.buf, true, {
    relative = "editor",
    style = "minimal",
    width = temp_width,
    height = temp_height,
    col = math.floor((vim.o.columns - temp_width) / 2),
    row = math.floor((vim.o.lines - temp_height) / 2),
    border = "rounded"
  })
  set_closers(self)

  local paths = {}
  for _, thread in pairs(burrow.threads) do
    table.insert(paths, thread.path)
  end

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, paths)

  local groupId = vim.api.nvim_create_augroup("spider_ui", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = self.buf,
    group = groupId,
    callback = function()
      local new_paths = vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)
      burrow.threads = map_paths_to_threads(burrow, paths, new_paths)
      vim.api.nvim_del_augroup_by_id(groupId)

      self:close_win()
      -- TODO something like storage/data-sync whatever
      Set_is_colony_stored(false)
    end,
  })
end

return Ui
