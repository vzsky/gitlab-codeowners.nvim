local function unique(tbl)
    local seen = {}
    local result = {}
    for _, v in ipairs(tbl) do
        if not seen[v] then
            table.insert(result, v)
            seen[v] = true
        end
    end
    return result
end

local function get_codeowners_file(repo_root)
  local locations = {
    repo_root .. "/CODEOWNERS",
    repo_root .. "/docs/CODEOWNERS",
    repo_root .. "/.gitlab/CODEOWNERS",
  }
  for _, loc in ipairs(locations) do
    local f = io.open(loc, "r")
    if f then f:close(); return loc end
  end
  return nil
end

local function glob_to_regex(p)

  if p == "*" then return "^/.*$" end
  if p:match("/$") then p = p .. "**/" end
  if not p:match("^/") then p = "/**/" .. p end

  p = string.gsub(p, "([%-%+%?%(%)])", "%%%1")

  p = string.gsub(p, "%*%*", "§")
  p = string.gsub(p, "%*", "[^/]*")
  p = string.gsub(p, "§/", ".*")

  p = "^" .. p .. "$"
  return p
end

local function read_sections(codeowners_file)
  local sections = {}
  local current_section = {}

  for line in io.lines(codeowners_file) do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      local section_name = trimmed:match("^%[(.-)%]$")
      if section_name then
        if #current_section > 0 then table.insert(sections, current_section) end
        current_section = {}
      elseif not trimmed:match("^#") then
        trimmed = trimmed:gsub("%s+#.*$", "")
        local pattern, owners = trimmed:match("([^%s]+)%s+(.+)$")
        if pattern and owners then
          local list = {}
          for o in owners:gmatch("%S+") do table.insert(list, o) end
          table.insert(current_section, {pattern = pattern, owners = list})
        end
      end
    end
  end

  if #current_section > 0 then table.insert(sections, current_section) end
  return sections
end

local function get_codeowners(path, repo_root)
  if not path:match("^/") then path = "/" .. path end

  local codeowners_file = get_codeowners_file(repo_root)
  if not codeowners_file then return {} end

  local sections = read_sections(codeowners_file)
  local owners = {}

  for _, rules in ipairs(sections) do
    local best = nil
    for _, r in ipairs(rules) do
      local regex = glob_to_regex(r.pattern)
      if path:match(regex) then best = r end
    end
    if best then
      for _, o in ipairs(best.owners) do
        table.insert(owners, o)
      end
    end
  end

  owners = unique(owners)
  return owners
end

return {
  get_codeowners = get_codeowners,
  glob_to_regex = glob_to_regex,
}

