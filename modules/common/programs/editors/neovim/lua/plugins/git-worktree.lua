return {
	"polarmutex/git-worktree.nvim",
	version = "^2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local hooks = require("git-worktree.hooks")
		hooks.register(hooks.type.SWITCH, function(path, prev_path)
			vim.notify("Switched to worktree: " .. path, vim.log.levels.INFO)
			vim.cmd("cd " .. path)
		end)
		hooks.register(hooks.type.SWITCH, hooks.builtins.update_current_buffer_on_switch)
	end,
	keys = {
		{
			"<leader>gw",
			function()
				Snacks.picker({
					title = "Git Worktrees",
					finder = function(opts, ctx)
						local Job = require("plenary.job")
						local items = {}
						local result = Job:new({
							command = "git",
							args = { "worktree", "list" },
						}):sync()
						for idx, line in ipairs(result) do
							local path, hash, branch = line:match("^(%S+)%s+(%S+)%s+%[?([^%]]*)%]?")
							items[#items + 1] = {
								idx = idx,
								text = line,
								file = path,
								branch = branch or "",
								hash = hash or "",
							}
						end
						return items
					end,
					format = function(item, _picker)
						local ret = {}
						ret[#ret + 1] = { item.branch, "Function" }
						ret[#ret + 1] = { " " }
						ret[#ret + 1] = { item.hash, "Comment" }
						ret[#ret + 1] = { " " }
						ret[#ret + 1] = { item.file, "Directory" }
						return ret
					end,
					confirm = function(picker, item)
						picker:close()
						if item then
							require("git-worktree").switch_worktree(item.file)
						end
					end,
					actions = {
						create = function(picker)
							picker:close()
							vim.ui.input({ prompt = "Branch name: " }, function(branch)
								if branch then
									require("git-worktree").create_worktree(branch, branch)
								end
							end)
						end,
						delete = function(picker)
							local item = picker:current()
							if item and item.branch ~= "" then
								picker:close()
								vim.ui.input({
									prompt = "Delete worktree '" .. item.branch .. "'? (y/N): ",
								}, function(confirm)
									if confirm == "y" then
										require("git-worktree").delete_worktree(item.file)
									end
								end)
							end
						end,
					},
				})
			end,
			desc = "Git Worktrees",
		},
		{
			"<leader>gW",
			function()
				vim.ui.input({ prompt = "Existing branch name: " }, function(branch)
					if branch then
						require("git-worktree").switch_worktree(branch)
					end
				end)
			end,
			desc = "Worktree from existing branch",
		},
		{
			"<leader>gN",
			function()
				vim.ui.input({ prompt = "New branch name: " }, function(branch)
					if branch then
						require("git-worktree").create_worktree(branch, branch)
					end
				end)
			end,
			desc = "Worktree from new branch",
		},
	},
}
