require "aragog.globals"
local utils = require "aragog.utils"
local clutch = require "aragog.clutch"

--TODO could be cool to to have custom stuff in this. Would also  require custom mapping functions.
---@class Thread
---@field path string
---@field buf integer | nil
---@field line integer | nil
---@field col integer | nil

---@class Burrow
---@field dir string
---@field name string | nil
---@field prev Thread | nil
---@field threads Thread[] | nil

---@class Colony
---@field burrows Burrow[] | nil
---@field current_burrow Burrow | nil
---@field current_thread Thread | nil
local Colony = {}
Colony.__index = Colony

---@return Colony
function Colony:new()
  local obj = setmetatable({}, self)

  local content = clutch.read_clutch()
  -- cases:
  --  non existent
  --  ""
  --  []
  --  null
  if not content or #content < 5 then
    return obj
  end

  local ok, res = pcall(vim.json.decode, content)
  assert(ok, "[Aragog] failed to decode json: ")
  obj.burrows = res

  local cwd = vim.fn.getcwd()
  for _, burrow in pairs(obj.burrows) do
    assert(burrow.dir, "[Aragog] burrow's dir must not be nil")
    if cwd == burrow.dir then
      obj.current_burrow = burrow
      Set_current_burrow_dir(burrow.dir, obj.current_burrow.name)
    end
    if burrow.prev then
      burrow.prev.buf = nil
    end

    for _, thread in pairs(burrow and burrow.threads or {}) do
      thread.buf = nil
    end
  end

  return obj
end

---@param thread Thread
---@return boolean
local function buf_fits_to_path(thread)
  if not thread.buf then
    return false
  end

  return vim.api.nvim_buf_get_name(thread.buf) == thread.path
end

---@param thread Thread
---@return boolean has_changed the position has chaged
local function set_thread_position(thread)
  local charPos = vim.fn.getcharpos(".")

  if thread.line and thread.line == charPos[2] and thread.col == thread.col then
    return false
  end

  thread.line = charPos[2]
  thread.col = charPos[3]
  return true
end

---Sets vim.g._aragog_colony_stored to false when position has changed
---@param thread Thread | nil
local function hidrate_thread(thread)
  if not thread then
    return
  end

  -- TODO could put that into a list and have a loop of custom shit to set
  local changed = set_thread_position(thread)
  if not changed then
    return
  end

  Set_is_colony_stored(false)
end

---@param buf integer
---@return Thread
local function create_thread(buf)
  ---@type Thread
  local thread = {
    buf = buf,
    path = vim.api.nvim_buf_get_name(buf)
  }

  hidrate_thread(thread)

  return thread
end

function Colony:on_dir_changed_pre()
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(buf) == "" or not self.current_burrow then
    return
  end
  self.current_burrow.prev = self.current_thread or create_thread(vim.api.nvim_get_current_buf())
end

---@param new_dir string
---@param workspaces workspace[] | nil
function Colony:on_dir_changed(new_dir, workspaces)
  if self.current_burrow and new_dir == self.current_burrow.dir then
    return
  end

  ---@type fun(burrow: Burrow)
  local on_found_burrow = function(burrow)
    self.current_burrow = burrow
    Set_current_burrow_dir(burrow.dir, burrow.name)
    if burrow.prev then
      local cold_dir = not burrow.prev.buf or not vim.api.nvim_buf_is_loaded(burrow.prev.buf)
      self:open_thread(burrow.prev)
      if cold_dir then
        -- when "cold starting" a buffer in a changed directory, other plugins (TS, Lsp, ...) may be confused hence this:
        vim.defer_fn(utils.fun(vim.api.nvim_cmd, { cmd = "e" }, {}), 1)
      end
    end
  end

  if self.burrows then
    for _, burrow in pairs(self.burrows) do
      if burrow.dir == new_dir then
        on_found_burrow(burrow)
        return
      end
    end
  end

  self.current_burrow = nil
  if workspaces then
    for _, ws in pairs(workspaces) do
      if new_dir == ws.path then
        Set_current_burrow_dir(new_dir, ws.name)
        return
      end
    end
  end

  print("testststtsts")
  -- fallback, not in workspaces nor burrows
  Set_current_burrow_dir(new_dir)
end

function Colony:hidrate_current_thread()
  hidrate_thread(self.current_thread)
end

---@param destThread Thread
function Colony:open_thread(destThread)
  assert(destThread.path, "[Aragog] destination thread must have a path")

  if destThread.buf and
      vim.api.nvim_buf_is_loaded(destThread.buf) and
      buf_fits_to_path(destThread) then
    vim.api.nvim_set_current_buf(destThread.buf)
  else
    -- If not found, open the file (will create buffer)
    vim.cmd("edit " .. vim.fn.fnameescape(destThread.path))
    destThread.buf = vim.api.nvim_get_current_buf()
    local pos = { destThread.line, destThread.col }
    if #pos == 2 then
      pcall(vim.api.nvim_win_set_cursor, 0, pos)
    end
  end

  hidrate_thread(destThread)
  self.current_thread = destThread
end

function Colony:append_buf_to_thread()
  local buf = vim.api.nvim_get_current_buf()
  ---@type Thread
  local new_thread = create_thread(buf)
  self.current_thread = new_thread

  ---#clean code
  if self.current_burrow then
    if not self.current_burrow.threads or #self.current_burrow.threads == 1 and self.current_burrow.threads[1].path == "" then
      self.current_burrow.threads = { new_thread }
    else
      table.insert(self.current_burrow.threads, new_thread)
    end
  else
    local new_burrow = {
      dir = vim.fn.getcwd(),
      threads = { new_thread }
    }

    if not self.burrows or #self.burrows == 0 then
      self.burrows = {
        new_burrow
      }
    else
      table.insert(self.burrows, new_burrow)
    end

    self.current_burrow = self.burrows[#self.burrows]
  end
end

return Colony
