local main = require("gitlab-codeowners.main")

local M = {}

local UNOWNED = "unowned"

local function this_path()
	return vim.api.nvim_buf_get_name(0)
end

function M.codeOwners()
	local path = this_path()
	local codeOwners = main.get_codeowners(path)

	if not codeOwners or next(codeOwners) == nil then
		return UNOWNED
	end

	return table.concat(codeOwners, ", ")
end

function M.shortCodeOwners()
	local path = this_path()
	local codeOwners = main.get_codeowners(path)

	if not codeOwners or next(codeOwners) == nil then
		return UNOWNED
	end

	if #codeOwners > 3 then
		return string.format("%s et al. (%d owners)", codeOwners[1], #codeOwners)
	else
		return table.concat(codeOwners, ", ")
	end
end

function M.setup(opts)
	opts = opts or {}
	vim.api.nvim_create_user_command("GitlabCodeowners", function ()
    print(M.codeOwners())
  end, { })
end

return M
