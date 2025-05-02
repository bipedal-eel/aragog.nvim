local file_io = require "aragog.clutch"

local input = [[
{
  "folders": [
    // here is a comment
    {
      "name": "root",
      "path": "./..",
    },
    {
      "name": "aragog",
      "path": "./../lua/aragog",
    },
    // here  is another comment
    {
      "name": "aragog/test",
      "path": "./../test/"
    },
    { hella invalid json },
    {
      "name": "ignores fields without names"
    }
    {
      "name": "dashes",
      "path": "./../lua/dir-with-dashes"
    }
  ],
  "settings": {}
}
]]

---@type workspace[]
local expected = {
  {
    name = "root",
    path = "./..",
  },
  {
    name = "aragog",
    path = "./../lua/aragog",
  },
  {
    name = "aragog/test",
    path = "./../test/",
  },
  {
    name = "dashes",
    path = "./../lua/dir-with-dashes",
  }
}


describe("parse vsw", function()
  it("can be parsed", function()
    local folders = file_io.parse_vsw_folders(input)
    assert.are.same(expected, folders)
  end)
end)
