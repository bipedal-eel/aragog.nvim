local utils = require("aragog.utils")
local telescope = require("aragog.telescope")

---@alias ui_type "threads" | "burrows" | "workspaces"
---@alias select_line_callback fun(type: ui_type, line_index: integer)

---@class AragogUi
---@field type ui_type
---@field win integer | nil
---@field buf integer | nil
---@field workspaces workspace[]
---@field select_line_callback select_line_callback
---@field persist_colony fun()
local Ui = {}
Ui.__index = Ui

---@param folders workspace[] | nil
---@param workspace_dir string | nil
---@param select_line_callback select_line_callback
function Ui:new(folders, workspace_dir, persist_colony, select_line_callback, opts)
	local obj = setmetatable({
		workspaces = {},
		persist_colony = persist_colony,
		select_line_callback = select_line_callback,
		opts = opts or {},
	}, self)

	if folders and workspace_dir then
		for _, folder in pairs(folders) do
			local full_path = string.gsub(vim.fn.fnamemodify(workspace_dir .. "/" .. folder.path, ":p"), "%/$", "")
			table.insert(obj.workspaces, { path = full_path, name = folder.name })
		end
	end

	return obj
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
		if vim.fn.isdirectory(new_dir) ~= 1 then
			new_dir = utils.root_dir_head .. new_dir
		end
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

		if new_path:sub(1, 1) == "/" then
			new_path = vim.fn.fnamemodify(new_path, ":.")
		end

		local index = vim.fn.indexof(rel_paths, string.format("v:val == %q", new_path))
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
---@param height integer
local function _open_win(self, height)
	self.buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.6)
	self.win = vim.api.nvim_open_win(self.buf, true, {
		relative = "editor",
		style = "minimal",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
	})
end

---@param self AragogUi
local function set_local_keymaps(self)
	assert(self.win, "[Aragog] win must not be nil")
	assert(self.buf, "[Aragog] buf must not be nil")

	local close_win = function()
		self:close_win()
	end
	vim.api.nvim_buf_set_keymap(self.buf, "n", "<ESC>", "", { callback = close_win, desc = "close window" })
	vim.api.nvim_buf_set_keymap(self.buf, "n", "q", "", { callback = close_win, desc = "close window" })
	vim.api.nvim_buf_set_keymap(self.buf, "n", "<CR>", "", {
		callback = function()
			local line = vim.fn.getcharpos(".")[2]
			self:close_win()
			self.select_line_callback(self.type, line)
		end,
		desc = "select line",
	})
end

---@param self AragogUi
---@param paths string[]
---@param lines_converter fun(lines: string[])
local function open_generic_window(self, paths, lines_converter)
	local height = math.max(6, #paths)
	_open_win(self, height)
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
	pcall(vim.api.nvim_win_close, self.win, true)
	self.buf = nil
	self.win = nil
end

---TODO restriction: "moving" not working
---@param colony Colony
function Ui:toggle_burrows(colony)
	if self.win then
		self:close_win()
		if self.type == "burrows" then
			return
		end
	end

	assert(colony, "[Aragog] colony cannot be nil")

	local paths = {}
	local root = vim.fn.fnamemodify(utils.root_dir_head, ":p")

	if colony.burrows then
		for _, burrow in pairs(colony.burrows) do
			local rel_path = burrow.dir:gsub("^" .. vim.pesc(root), "")
			local stripped = rel_path ~= burrow.dir
			table.insert(paths, stripped and "/" .. rel_path or burrow.dir)
		end
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

---@param colony Colony
function Ui:toggle_threads(colony)
	if self.win then
		self:close_win()
		if self.type == "threads" then
			return
		end
	end

	local burrow = colony.current_burrow or { dir = vim.fn.getcwd() }

	local paths = {}
	for _, thread in pairs(burrow.threads and burrow.threads or {}) do
		table.insert(paths, vim.fn.fnamemodify(thread.path, ":."))
	end

	local lines_to_threads = function(lines)
		burrow.threads = map_paths_to_threads(burrow, paths, lines)
		if #burrow.threads ~= 0 then
			colony.current_burrow = burrow

			if not colony.burrows or #colony.burrows == 0 then
				colony.burrows = { burrow }
			end
		end
	end

	open_generic_window(self, paths, lines_to_threads)
	self.type = "threads"
end

function Ui:toggle_workspace()
	if not self.workspaces or #self.workspaces == 0 then
		return
	end

	telescope.workspace_picker(self.workspaces, function(idx)
		self.select_line_callback("workspaces", idx)
		self.persist_colony()
	end)
end

return Ui
