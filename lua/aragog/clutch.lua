---@class workspace
---@field path string
---@field name string | nil
---@field idx integer | nil

---@class file_io
---@field root_dir string
---@field store_dir string
---@field workspaces workspace[] | nil
local M = {}

---@return workspace[] | nil
local function workspaces()
	local matches = vim.fn.glob(M.root_dir .. "/.vscode/*.code-workspace", true, true)
	if #matches == 0 then
		return
	end

	local file = io.open(matches[1], "r")
	if not file then
		return
	end
	local content = file:read("a")

	return M.parse_vsw_folders(content)
end

function M.init()
	local data_path = vim.fn.stdpath("data") .. "/aragog.clutch"
	local dir = vim.fn.finddir(data_path)
	if dir == "" then
		vim.fn.mkdir(data_path)
	end

	--   TODO this in less weird to get actual cwd accounting for start param
	--   local raw_arg = vim.fn.argv(0)
	-- local resolved_path
	--
	-- if raw_arg ~= "" then
	--     -- ':p' handles the heavy lifting:
	--     -- It takes the arg and expands it relative to the current CWD
	--     -- into a full absolute path, resolving '.' and '..'
	--     resolved_path = vim.fn.fnamemodify(raw_arg, ':p')
	--
	--     -- If it's a file, you might want just the directory
	--     if vim.fn.isdirectory(resolved_path) == 0 then
	--         resolved_path = vim.fn.fnamemodify(resolved_path, ':h')
	--     end
	-- else
	--     resolved_path = vim.fn.getcwd()
	-- end

	M.root_dir = vim.fn.getcwd()
	M.store_dir = data_path .. "/" .. vim.fn.substitute(M.root_dir, "/", "_", "g")
	M.workspaces = workspaces()
end

---@return string | nil
function M.read_clutch()
	assert(M.store_dir, "[Aragog] dir should not be nil")
	local file = io.open(M.store_dir, "r")
	if not file then
		return
	end

	local content = file:read("a")
	file:close()
	return content
end

---@param content string content to perstist
function M.write_to_clutch(content)
	local file = io.open(M.store_dir, "w")

	assert(file, "[Aragog] failed to open file for writing: " .. M.store_dir)

	file:write(content)

	file:close()
end

---parses vscode workspace folder
---@param input string
---@return workspace[]
function M.parse_vsw_folders(input)
	---@type workspace[]
	local folders = {}
	---@type workspace | nil
	local current = nil

	local lines = vim.split(input, "\n")
	local count = 1

	for i = count, #lines, 1 do
		local line = lines[i]:match("^%s*(.-)%s*$") -- trim
		count = count + 1
		-- Skip comments
		if line:match("^//") or line == "" then
			goto continue
		end
		if line:match('"folders"%s*:%s*%[') then
			break
		end
		::continue::
	end

	for i = count, #lines, 1 do
		local line = lines[i]:match("^%s*(.-)%s*$") -- trim
		if line == "]," or line == "]" then
			break
		end
		if line == "{" then
			---@diagnostic disable-next-line: missing-fields
			current = {}
			goto continue
		elseif line == "}," or line == "}" then
			-- ignore folders without a path
			if current and current.path then
				table.insert(folders, current)
				current = nil
			end
			goto continue
		end

		local key, value = line:match('"([^"]+)"%s*:%s*"([^"]+)"')
		if key and value and current then
			current[key] = value
		end
		::continue::
	end

	return folders
end

return M
