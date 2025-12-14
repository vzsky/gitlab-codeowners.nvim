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

	for line in io.lines(codeowners_file) do
		local trimmed = line:match("^%s*(.-)%s*$")
		if trimmed ~= "" then
			local section_name = trimmed:match("^%[(.-)%]$")
			if section_name then
				if #current_section > 0 then
					table.insert(sections, current_section)
				end
				current_section = {}
			elseif not trimmed:match("^#") then
				trimmed = trimmed:gsub("%s+#.*$", "")
				local pattern, owners = trimmed:match("([^%s]+)%s+(.+)$")
				if pattern and owners then
					local list = {}
					for o in owners:gmatch("%S+") do
						table.insert(list, o)
					end
					table.insert(current_section, { pattern = pattern, owners = list })
				end
			end
		end
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
  if not path then return nil end

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
