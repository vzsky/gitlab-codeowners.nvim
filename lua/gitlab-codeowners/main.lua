local M = {}

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

local function file_exists(p)
	local f = io.open(p, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function dirname(p)
	return p:match("^(.*)/[^/]*$") or "."
end

local function path_relative_to_root(path, root_repo)
	if path:sub(1, #root_repo) ~= root_repo then
		return nil
	end

	local rel = path:sub(#root_repo + 1)
	if rel == "" then
		return "/"
	end

	return rel
end

function M.get_codeowners_file(path)
  -- TODO: this approach will not work great with files in .gitlab or in docs
	local locations_from_root = {
		"/CODEOWNERS",
		"/docs/CODEOWNERS",
		"/.gitlab/CODEOWNERS",
	}

	local dir = dirname(path)

	while dir do
		for _, loc in ipairs(locations_from_root) do
			local candidate = dir .. loc
			if file_exists(candidate) then
				return { repo = dir, co_file = candidate }
			end
		end

		if dir == "/" or dir == "." then
			break
		end
		dir = dirname(dir)
	end
	return nil
end

local function glob_to_regex(p)
	if p == "*" then
		return "^/.*$"
	end
	if p:match("/$") then
		p = p .. "**/"
	end
	if not p:match("^/") then
		p = "/**/" .. p
	end

	p = string.gsub(p, "([%-%+%?%(%)])", "%%%1")

	p = string.gsub(p, "%*%*", "§")
	p = string.gsub(p, "%*", "[^/]*")
	p = string.gsub(p, "§/", ".*")

	p = "^" .. p .. "$"
	return p
end

function M.read_sections(codeowners_file)
  local sections = {}
  local current_section = {}
  local current_defowner = {}

  local function handle_line(line)
    line = line:match("^[^#]*")
    line = line:match("^%s*(.-)%s*$")
    if line == "" then
      return
    end

    local section_name, owner_str = line:match("^%[(.-)%](.*)$")
    if section_name then
      if #current_section > 0 then
        table.insert(sections, current_section)
      end

      current_section = {}
      current_defowner = {}

      for o in owner_str:gmatch("%S+") do
        table.insert(current_defowner, o)
      end

      return
    end

    local pattern, owners_str = line:match("([^%s]+)%s*(.*)")

    local owners = {}
    if owners_str then
      for o in owners_str:gmatch("%S+") do
        table.insert(owners, o)
      end
    end

    if #owners == 0 then
      for _, o in ipairs(current_defowner) do
        table.insert(owners, o)
      end
    end

    if not pattern or #owners == 0 then
      return
    end

    table.insert(current_section, {
      pattern = pattern,
      owners = owners,
    })
  end

  for line in io.lines(codeowners_file) do
    handle_line(line)
  end

  if #current_section > 0 then
    table.insert(sections, current_section)
  end

  return sections
end

function M.get_codeowners(path)
  local result = M.get_codeowners_file(path)
  if not result or not result.co_file then
    return nil
  end

  local codeowners_file = result.co_file
  local root_repo = result.repo
  path = path_relative_to_root(path, root_repo)
  if not path then
    return nil
  end

  local sections = M.read_sections(codeowners_file)
  local owners = {}

  for _, rules in ipairs(sections) do
    local best = nil

    for _, r in ipairs(rules) do
      local regex = glob_to_regex(r.pattern)
      if path:match(regex) then
        best = r
      end
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

return M
