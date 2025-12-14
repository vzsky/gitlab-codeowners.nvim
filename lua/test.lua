local function same_set(a, b)
  if #a ~= #b then return false end
  table.sort(a)
  table.sort(b)
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local function list_to_string(t)
  local out = {}
  for _, v in ipairs(t) do table.insert(out, tostring(v)) end
  return "{" .. table.concat(out, ", ") .. "}"
end

local function run(label, fn)
	print("TEST:", label)
	local ok, err = pcall(fn)
	if not ok then
		print("FAILED:", err)
		os.exit(1)
	end
	print("OK\n")
end

----------------------------------------------------
-- create a fake repo with CODEOWNERS inside /tmp
----------------------------------------------------
local repo = "/tmp/codeowners_test"
os.execute("rm -rf " .. repo)
os.execute("mkdir -p " .. repo .. "/.gitlab")

local M = dofile("./lua/main.lua")

local function assert_owners(file_name, exp_owners)
  local owners = M.get_codeowners(file_name, repo)
  assert(
    same_set(owners, exp_owners),
    "owners mismatch for: " .. file_name ..
    " got " .. list_to_string(owners) ..
    " expected " .. list_to_string(exp_owners)
  )
end


local function assert_owner(file_name, exp_owner)
	assert_owners(file_name, { exp_owner })
end

local function write(path, content)
	local f = assert(io.open(path, "w"))
	f:write(content)
	f:close()
end

write(repo .. "/.gitlab/CODEOWNERS",
[[
# Specify a default **Code Owner** for all files with a wildcard:
* @default-owner

# Specify [multiple] Code Owners to a specific file:
README.* @readme-team

*.md @md-owner @md-owner2

README.md @readme-md

/docs/ @all-docs
/docs/* @root-docs
/docs/**/*.md @markdown-docs  # Match specific file types in any subdirectory
]])

run("README.md matches both top-level and nested", function()
	assert_owner("something/README.md", "@readme-md")
	assert_owner("README.md", "@readme-md")
	assert_owner("/README.md", "@readme-md")
	assert_owner("/one/two/README.md", "@readme-md")
end)

run("other.md matches both top-level and nested", function()
	local md_owners = { "@md-owner", "@md-owner2" }
	assert_owners("mdOwners/abc.md", md_owners)
	assert_owners("something.md", md_owners)
	assert_owners("/one/two/xyz.md", md_owners)
end)

run("docs directory patterns", function()
  assert_owner("docs/a/file.txt", "@all-docs")
  assert_owner("docs/b/c/d.md", "@markdown-docs")
  assert_owner("docs/file1.txt", "@root-docs")
  assert_owner("docs/subdir/file2.txt", "@all-docs")
  assert_owner("docs/subdir/file.md", "@markdown-docs")
  assert_owner("docs/file.md", "@markdown-docs")
  assert_owners("/sth/docs/file.md", {"@md-owner", "@md-owner2"})
end)

run("default wildcard *", function()
  assert_owner("random.txt", "@default-owner")
  assert_owner("foo/bar/baz.js", "@default-owner")
  assert_owner("/another/file.py", "@default-owner")
end)

run("priority tests", function()
	local md_owners = { "@md-owner", "@md-owner2" }
  assert_owner("README.md", "@readme-md")
  assert_owner("docs/README.md", "@markdown-docs")
  assert_owners("notes.md", md_owners)
  assert_owner("/docs/notes.md", "@markdown-docs")
  assert_owners("something/docs/notes.md", md_owners)
end)

write(repo .. "/CODEOWNERS",
[[
* @default-owner
*.md @md-owner
/docs/ @all-docs

[Docs]
/docs/ @all-docs
/docs/*.md @all-docs 
README.md @readme 

[Misc] 
/docs/*.misc @misc
]])

run("section", function()
  assert_owners("README.md", {"@md-owner", "@readme"})
  assert_owners("/docs/README.md", {"@all-docs", "@readme"})
  assert_owners("docs/README.md", {"@all-docs", "@readme"})
  assert_owners("/sth/docs/README.md", {"@md-owner", "@readme"})
  assert_owner("something.txt", "@default-owner")

  -- repeated entry
  assert_owners("/docs/something.misc", {"@all-docs", "@misc"})
  assert_owner("/docs/file.md", "@all-docs")
end)

print("ALL TESTS PASSED")
