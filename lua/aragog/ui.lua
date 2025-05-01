local utils = require "aragog.utils"

local VIRT_NS = vim.api.nvim_create_namespace("aragog_virtual_index")

---@class AragogUiOpts
---@field debug boolean | nil

---@alias ui_type "threads" | "burrows"
---@alias Select_line_callback fun(type: ui_type, line_index: integer)

---@class AragogUi
---@field type ui_type
---@field win integer | nil
---@field buf integer | nil
---@field select_line_callback Select_line_callback
---@field persist_colony function
---@field opts AragogUiOpts
local Ui = {}
Ui.__index = Ui

---@param persist_colony function
---@param select_line_callback Select_line_callback
---@param opts AragogUiOpts | nil
function Ui:new(persist_colony, select_line_callback, opts)
  local obj = setmetatable({
    persist_colony = persist_colony,
    select_line_callback = select_line_callback,
    opts = opts or {},
  }, self)
  return obj
end

---@type workspace[]
Ui.workspace_paths_obj = {}
---@type string[]
Ui.workspace_paths_or_names = {}

---@param folders workspace[]
---@param workspace_dir string
function Ui:init_workspace_paths(folders, workspace_dir)
  for _, folder in pairs(folders) do
    local _name = folder.name or folder.path
    table.insert(Ui.workspace_paths_or_names, _name)

    local full_path = string.gsub(vim.fn.fnamemodify(workspace_dir .. "/" .. folder.path, ":p"), "%/$", "")
    table.insert(Ui.workspace_paths_obj, { path = full_path })
  end
end

---@type function
---@param burrows Burrow[]
---@param new_dirs string[]
---@return Burrow[]
local function map_paths_to_burrows(burrows, new_dirs)
  ---@type Burrow[]
  local new_burrows = {}
  local dirs = {}

  for _, burrow in pairs(burrows) do
    table.insert(dirs, burrow.dir)
  end

  for i, new_dir in pairs(new_dirs) do
    if new_dir == "" then
      goto continue
    end
    new_dir = utils.root_dir_head .. new_dir
    if new_dir:sub(-1) == "/" then
      new_dir = new_dir:sub(0, -2)
    end

    if burrows[i] and new_dir == burrows[i].dir then
      table.insert(new_burrows, burrows[i])
      goto continue
    end

    local index = vim.fn.indexof(dirs, string.format("v:val == %q", new_dirs[i]))
    if index ~= -1 then
      table.insert(new_burrows, burrows[index + 1])
    else
      table.insert(new_burrows, { dir = new_dir })
    end
    ::continue::
  end

  return new_burrows
end

---@type function
---@param burrow Burrow
---@param rel_paths string[]
---@param rel_new_paths string[]
---@return Thread[]
local function map_paths_to_threads(burrow, rel_paths, rel_new_paths)
  ---@type Thread[]
  local new_threads = {}
  local cwd = vim.fn.getcwd()
  for i, new_path in pairs(rel_new_paths) do
    if new_path == "" then
      goto continue
    end

    if new_path == rel_paths[i] then
      table.insert(new_threads, burrow.threads[i])
      goto continue
    end

    local index = vim.fn.indexof(rel_paths, string.format("v:val == %q", rel_new_paths[i]))
    if index ~= -1 then
      table.insert(new_threads, burrow.threads[index + 1])
    else
      table.insert(new_threads, { path = cwd .. "/" .. new_path })
    end
    ::continue::
  end

  return new_threads
end

---@param self AragogUi
local function set_local_keymaps(self)
  assert(self.win, "win must not be nil")
  assert(self.buf, "buf must not be nil")

  local close_win = function() self:close_win() end
  vim.api.nvim_buf_set_keymap(self.buf, "n", "<ESC>", "", { callback = close_win, desc = "close window" })
  vim.api.nvim_buf_set_keymap(self.buf, "n", "q", "", { callback = close_win, desc = "close window" })
  vim.api.nvim_buf_set_keymap(self.buf, "n", "<CR>", "", {
    callback = function()
      local line = vim.fn.getcharpos(".")[2]
      self:close_win()
      self.select_line_callback(self.type, line)
    end
  })
end

---@param self AragogUi
---@param paths string[]
---@param lines_converter fun(lines: string[])
local function open_generic_window(self, paths, lines_converter)
  self.buf = vim.api.nvim_create_buf(false, true)
  local temp_width = math.floor(vim.o.columns * 0.6)
  -- TODO take in count of workspace file
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
  -- TODO optional for type workspace-file
  set_local_keymaps(self)

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, paths)

  local groupId = vim.api.nvim_create_augroup("spider_ui", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = self.buf,
    group = groupId,
    callback = function()
      lines_converter(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false))
      vim.api.nvim_del_augroup_by_id(groupId)

      self.buf = nil
      self.win = nil
      self.persist_colony()
    end,
  })
end

function Ui:close_win()
  vim.api.nvim_win_close(self.win, true)
  self.buf = nil
  self.win = nil
end

---TODO restriction: "moving" not working
---@param colony Colony | nil
function Ui:toggle_burrows(colony)
  if self.win then
    self:close_win()
    if self.type == "burrows" then
      return
    end
  end

  if not colony then
    return
  end

  local paths = {}
  local root = vim.fn.fnamemodify(utils.root_dir_head, ":p")

  for _, burrow in pairs(colony.burrows or {}) do
    local rel_path = burrow.dir:gsub("^" .. vim.pesc(root), "")
    table.insert(paths, rel_path ~= "" and "/" .. rel_path or burrow.dir)
  end

  local lines_to_burrows = function(lines)
    if #lines == 0 then
      return
    end
    colony.burrows = map_paths_to_burrows(colony.burrows or {}, lines)

    if #colony.burrows == 1 then
      colony.current_burrow = colony.burrows[1]
    end
  end

  open_generic_window(self, paths, lines_to_burrows)
  self.type = "burrows"
end

---@param burrow Burrow | nil
function Ui:toggle_threads(burrow)
  if self.win then
    self:close_win()
    if self.type == "threads" then
      return
    end
  end

  if not burrow then
    return
  end

  local paths = {}
  for _, thread in pairs(burrow.threads and burrow.threads or {}) do
    table.insert(paths, vim.fn.fnamemodify(thread.path, ":."))
  end

  local lines_to_threads = function(lines)
    burrow.threads = map_paths_to_threads(burrow, paths, lines)
  end

  open_generic_window(self, paths, lines_to_threads)
  self.type = "threads"
end

---TODO restrictions: "moving" does not work and duplicates are possible (old position not cleaned (not a big issue))
---@param folders workspace[]
---@param burrows Burrow[] | nil
---@return Burrow[] new_burrows
function Ui:toggle_workspace(folders, burrows)
  for i, folder in pairs(folders) do
    if not burrows then
      goto continue
    end
    for j, burrow in pairs(burrows) do
      if Ui.workspace_paths_obj[i] and Ui.workspace_paths_obj[i].path == burrow.dir then
        burrow.name = folder.name
        Ui.workspace_paths_obj[i].idx = j
      end
    end
    ::continue::
  end

  local line_count = #Ui.workspace_paths_or_names
  local width = math.floor(vim.o.columns * 0.6)
  local height = 6 > line_count and 6 or line_count
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  self.buf = vim.api.nvim_create_buf(false, true)
  self.win = vim.api.nvim_open_win(self.buf, true, {
    relative = "editor",
    style = "minimal",
    width = width,
    height = height,
    col = col,
    row = row,
    border = "rounded"
  })
  set_local_keymaps(self)

  local set_virtual_indeces = function()
    vim.api.nvim_buf_clear_namespace(self.buf, VIRT_NS, 0, -1)
    for i = 0, line_count - 1, 1 do
      vim.api.nvim_buf_set_extmark(self.buf, VIRT_NS, i, 0, {
        virt_text = { { string.format("%s  ", Ui.workspace_paths_obj[i + 1].idx or " "), "Error" } }, -- Error for red, Comment for semi-transparent, Info for regular
        virt_text_pos = "inline",
        hl_mode = "combine",
      })
    end
  end

  local pin_cb = function(i)
    local idx = vim.fn.getcharpos(".")[2]
    local path = Ui.workspace_paths_obj[idx].path
    for _, obj in pairs(Ui.workspace_paths_obj) do
      if obj.idx == i then
        obj.idx = nil
      end
    end
    Ui.workspace_paths_obj[idx].idx = i

    if not burrows then
      burrows = {}
    end
    for _, burrow in pairs(burrows) do
      if burrow.dir == path then
        burrows[i] = Ui.workspace_paths_obj[idx]
      end
    end
    burrows[i] = { dir = path }
    set_virtual_indeces()
  end

  vim.api.nvim_buf_set_keymap(self.buf, "n", "1", "", {
    callback = utils.fun(pin_cb, 1),
    desc = "pin as first burrow"
  })

  vim.api.nvim_buf_set_keymap(self.buf, "n", "2", "", {
    callback = utils.fun(pin_cb, 2),
    desc = "pin as second burrow"
  })

  vim.api.nvim_buf_set_keymap(self.buf, "n", "3", "", {
    callback = utils.fun(pin_cb, 3),
    desc = "pin as third burrow"
  })

  vim.api.nvim_buf_set_keymap(self.buf, "n", "4", "", {
    callback = utils.fun(pin_cb, 4),
    desc = "pin as third burrow"
  })

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, Ui.workspace_paths_or_names)
  vim.api.nvim_set_option_value("modifiable", false, { scope = "local", buf = self.buf })
  vim.api.nvim_set_option_value("readonly", true, { scope = "local", buf = self.buf })
  vim.api.nvim_set_option_value("relativenumber", true, { scope = "local", win = self.win })

  set_virtual_indeces()

  local groupId = vim.api.nvim_create_augroup("spider_ui", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = self.buf,
    group = groupId,
    callback = function()
      -- lines_converter(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false))
      vim.api.nvim_del_augroup_by_id(groupId)

      self.buf = nil
      self.win = nil
      self.persist_colony()
    end,
  })

  return burrows
end

return Ui
