C = {
	reset = "\27[0m",
	red = "\27[31m",
	green = "\27[32m",
	yellow = "\27[33m",
}

local health = {
	has_error = false,

	start = function(_, s)
		print("START: " .. s)
	end,

	error = function(self, s)
		print(C.red .. "ERROR: " .. C.reset .. s)
		self.has_error = true
	end,

	ok = function(_, s)
		print(C.green .. "OK: ".. C.reset .. s)
	end,
}

local function same_set(a, b)
	if #a ~= #b then
		return false
	end
	table.sort(a)
	table.sort(b)
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function list_to_string(t)
	local out = {}
	for _, v in ipairs(t) do
		table.insert(out, tostring(v))
	end
	return "{" .. table.concat(out, ", ") .. "}"
end

local function run(label, fn)
	health:start("Tests " .. label)
	local ok, err = pcall(fn)
	if not ok then
		health:error("Failed " .. err)
		return
	end
	health:ok("Passed")
end

----------------------------------------------------
-- create a fake repo with CODEOWNERS inside /tmp
----------------------------------------------------
local repo = "/tmp/codeowners_test"
os.execute("rm -rf " .. repo)

local main = require("lua.gitlab-codeowners.main")

local function assert_owners(file_name, exp_owners)
	local owners = main.get_codeowners(repo .. file_name)
	assert(
		same_set(owners, exp_owners),
		"owners mismatch for: "
			.. file_name
			.. " got "
			.. list_to_string(owners)
			.. " expected "
			.. list_to_string(exp_owners)
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

local function test_1()
  os.execute("mkdir -p " .. repo .. "/.gitlab")
	write(
		repo .. "/.gitlab/CODEOWNERS",
		[[
  # Specify a default **Code Owner** for all files with a wildcard:
  * @default-owner

  # Specify [multiple] Code Owners to a specific file:
  README.* @readme-team

  *.md @md-owner @md-owner2

  README.md @readme-md

  /documents/ @all-docs
  /documents/* @root-docs
  /documents/**/*.md @markdown-docs  # Match specific file types in any subdirectory
  ]]
	)

	run(".gitlab/CODEOWNERS found", function()
		local co_file = main.get_codeowners_file(repo .. "/something")
		assert(co_file)
    assert(co_file.co_file == repo .. "/.gitlab/CODEOWNERS")
    assert(co_file.repo == repo)
	end)

	run("README.md matches both top-level and nested", function()
		assert_owner("/something/README.md", "@readme-md")
		assert_owner("/README.md", "@readme-md")
		assert_owner("/one/two/README.md", "@readme-md")
	end)

	run("other.md matches both top-level and nested", function()
		local md_owners = { "@md-owner", "@md-owner2" }
		assert_owners("/mdOwners/abc.md", md_owners)
		assert_owners("/something.md", md_owners)
		assert_owners("/one/two/xyz.md", md_owners)
	end)

	run("docs directory patterns", function()
		assert_owner("/documents/a/file.txt", "@all-docs")
		assert_owner("/documents/b/c/d.md", "@markdown-docs")
		assert_owner("/documents/file1.txt", "@root-docs")
		assert_owner("/documents/subdir/file2.txt", "@all-docs")
		assert_owner("/documents/subdir/file.md", "@markdown-docs")
		assert_owner("/documents/file.md", "@markdown-docs")
		assert_owners("/sth/documents/file.md", { "@md-owner", "@md-owner2" })
	end)

	run("default wildcard *", function()
		assert_owner("/random.txt", "@default-owner")
		assert_owner("/foo/bar/baz.js", "@default-owner")
		assert_owner("/another/file.py", "@default-owner")
	end)

	run("priority tests", function()
		local md_owners = { "@md-owner", "@md-owner2" }
		assert_owner("/README.md", "@readme-md")
		assert_owner("/documents/README.md", "@markdown-docs")
		assert_owners("/notes.md", md_owners)
		assert_owner("/documents/notes.md", "@markdown-docs")
		assert_owners("/something/documents/notes.md", md_owners)
	end)
end

local function test_2()
  os.execute("mkdir -p " .. repo .. "/docs")
	write(
		repo .. "/docs/CODEOWNERS",
		[[
  * @default-owner
  *.md @md-owner
  /documents/ @all-docs

  [Docs]
  /documents/ @all-docs
  /documents/*.md @all-docs
  README.md @readme

  [Misc]
  /documents/*.misc @misc
  ]]
	)

	run("docs/CODEOWNERS overwrites .gitlab/", function()
		local co_file = main.get_codeowners_file(repo .. "/something/a/b/c")
		assert(co_file)
    assert(co_file.co_file == repo .. "/docs/CODEOWNERS")
    assert(co_file.repo == repo)
	end)

	run("section", function()
		assert_owners("/README.md", { "@md-owner", "@readme" })
		assert_owners("/documents/README.md", { "@all-docs", "@readme" })
		assert_owners("/sth/docs/README.md", { "@md-owner", "@readme" })
		assert_owner("/something.txt", "@default-owner")

		-- repeated entry
		assert_owners("/documents/something.misc", { "@all-docs", "@misc" })
		assert_owner("/documents/file.md", "@all-docs")
	end)
end

local function test_3()
	write(
		repo .. "/CODEOWNERS",
		[[
  * @default-owner
  *.md @md-owner
  /documents/ @all-docs

  [Docs] @doc-default
  /documents/ 
  /documents/*.md @all-docs
  README.md 

  [Algorithm] @cpp-master @algo-team
  /cpp/ 
  /algo/*.md @all-docs
  /algo/*.txt @algo-team
  /cpp/includes/ @cpp-master
  ]]
	)

	run("/CODEOWNERS overwrites docs/", function()
		local co_file = main.get_codeowners_file(repo .. "/something/a/b/c")
		assert(co_file and co_file.co_file == repo .. "/CODEOWNERS")
	end)

	run("section default ", function()
		assert_owners("/README.md", { "@md-owner", "@doc-default" })
		assert_owners("/documents/README.md", { "@all-docs", "@doc-default" })
		assert_owner("/documents/FILE.md", "@all-docs")
		assert_owners("/sth/documents/README.md", { "@md-owner", "@doc-default" })
		assert_owner("/something.txt", "@default-owner")
	end)

  run("section default more than 1 owners", function()
    assert_owners("/cpp/main.cpp", { "@default-owner", "@cpp-master", "@algo-team" })
    assert_owners("/algo/foo.md", { "@md-owner", "@all-docs" })
    assert_owners("/algo/bar.txt", { "@default-owner", "@algo-team" })
    assert_owners("/cpp/includes/header.h", { "@default-owner", "@cpp-master" })
    assert_owner("/other/path/file.txt", "@default-owner")
  end)


end

local function check()
	test_1()
	test_2()
  test_3()
	if health.has_error then
		os.exit(1)
	end
end

check()
