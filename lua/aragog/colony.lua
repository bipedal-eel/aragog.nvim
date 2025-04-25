require "aragog.globals"
local file_io = require "aragog.file_io"

--Maybe extract colony
--    colony:add_burrow
--    ---when adding thread abs path should be set. Also when allowing whatever via ui (compare harpoon)
--    ---destThread.path = vim.fn.fnamemodify(file_to_add, ":p")
--    colony:add_thread
--    colony:update_threads
--    colony:update_burrow
--
--local current_burrow
--function M.switch_burrow(destBurrow)
--end
--
--autocmd BufLeave
--check if still in current_burrow and adjust (switch to appropriate)
--  vim.startswith(s, prefix)

---@class ColonyOpts
---@field debug boolean | nil

--TODO could be cool to to have custom stuff in this. Would also  require custom mapping functions.
---@class Thread
---@field path string
---@field bufnr integer | nil
---@field line integer | nil
---@field col integer | nil

---@class Burrow
---@field dir string | nil
---@field threads Thread[]

---@class Colony
---@field opts ColonyOpts
---@field burrows Burrow[]
---@field current_burrow Burrow | nil
---@field current_thread Thread | nil
local Colony = {}
Colony.__index = Colony

---@param opts ColonyOpts | nil
---@return Colony
function Colony:new(opts)
  local obj = setmetatable({
    opts = opts or {}
  }, self)

  local content = file_io.read_clutch()
  if not content or content == "" then
    return obj
  end

  local ok, res = pcall(vim.json.decode, content)
  if not ok then
    error("[Aragog] failed to decode json: " .. res)
  end
  obj.burrows = res

  local cwd = vim.fn.getcwd()
  for _, burrow in pairs(obj.burrows) do
    if cwd == burrow.dir then
      obj.current_burrow = burrow
    end

    for _, thread in pairs(burrow.threads) do
      thread.bufnr = nil
    end
  end

  return obj
end

---@param thread Thread
---@return boolean
local function buf_fits_to_path(thread)
  if not thread.bufnr then
    return false
  end

  return vim.api.nvim_buf_get_name(thread.bufnr) == thread.path
end

---@param thread Thread
---@return boolean has_changed the position has chaged
local function set_thread_position(thread)
  local charPos = vim.fn.getcharpos(".")

  if thread.line == charPos[2] and thread.col == thread.col then
    return false
  end

  thread.line = charPos[2]
  thread.col = charPos[3]
  return true
end

---Sets vim.g._aragog_colony_stored to false when position has changed
---@param self Colony
---@param thread Thread | nil
local function hidrate_thread(self, thread)
  if not thread then
    return
  end
  if self.opts.debug then
    print("hidrate_thread")
  end

  -- TODO could put that into a list and have a loop of custom shit to set
  local changed = set_thread_position(thread)

  if not changed then
    return
  end

  Set_is_colony_stored(false)
end

function Colony:on_change_dir(new_dir)
  if self.current_burrow and new_dir == self.current_burrow.dir then
    print("was the same dir")
    return
  end

  for _, burrow in pairs(self.burrows) do
    if burrow.dir == new_dir then
      self.current_burrow = burrow
      print("found dir")
      return
    end
  end

  print("no dir found")
  self.current_burrow = nil
end

function Colony:hidrate_current_thread()
  hidrate_thread(self, self.current_thread)
end

---@param destThread Thread
function Colony:open_file_buffer(destThread)
  if destThread.path == "" then
    return
  end

  if destThread.bufnr and
      vim.api.nvim_buf_is_loaded(destThread.bufnr) and
      buf_fits_to_path(destThread) then
    vim.api.nvim_set_current_buf(destThread.bufnr)
    vim.notify("Switched to existing buffer: " .. destThread.path, vim.log.levels.INFO)
  else
    -- If not found, open the file (will create buffer)
    vim.cmd("edit " .. vim.fn.fnameescape(destThread.path))
    destThread.bufnr = vim.api.nvim_get_current_buf()
    local pos = { destThread.line, destThread.col }
    if #pos == 2 then
      vim.api.nvim_win_set_cursor(0, pos)
    end

    vim.notify("Opened file: " .. destThread.path, vim.log.levels.INFO)
  end

  hidrate_thread(self, destThread)
  self.current_thread = destThread
end

function Colony:append_buf_to_thread()
  local bufnr = vim.api.nvim_get_current_buf()
  ---@type Thread
  local new_thread = {
    path = vim.api.nvim_buf_get_name(bufnr),
    bufnr = bufnr,
  }
  set_thread_position(new_thread)

  ---#clean code
  if self.current_burrow then
    if #self.current_burrow.threads == 1 and self.current_burrow.threads[1].path == "" then
      self.current_burrow.threads = { new_thread }
    else
      assert(self.current_burrow.threads, "[Aragog] current burrow does not have threads")
      table.insert(self.current_burrow.threads, new_thread)
    end
  else
    local new_burrow = {
      dir = vim.fn.getcwd(),
      threads = { new_thread }
    }

    if #self.burrows == 0 then
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
