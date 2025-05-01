---@alias workspace { name: string | nil, path: string }

local M = {}

---parses vscode workspace folder
---@param input string
---@return workspace[]
function M.vsc_folders(input)
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
      current = {}
      goto continue
    elseif line == "}," or line == "}" then
      if current then
        table.insert(folders, current)
        current = nil
      end
      goto continue
    end

    -- Parse lines like: "name": "root",
    local key, value = line:match('"([^"]+)"%s*:%s*"([^"]+)"')
    if key and value and current then
      current[key] = value
    end

    ::continue::
  end

  return folders
end

return M
