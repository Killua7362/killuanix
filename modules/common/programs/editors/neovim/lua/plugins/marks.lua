return {
	"chentoast/marks.nvim",
	event = "VeryLazy",
	opts = {
		-- whether to map keybinds or not. default true
		default_mappings = true,
		-- which builtin marks to show. default {}
		builtin_marks = { ".", "<", ">", "^" },
		-- whether movements cycle back to the beginning/end of buffer. default true
		cyclic = true,
		-- whether the shada file is updated after modifying uppercase marks. default false
		force_write_shada = false,
		-- how often (in ms) to redraw signs/recompute mark positions.
		-- higher values will have better performance but may cause visual lag,
		-- while lower values may cause performance penalties. default 150.
		refresh_interval = 250,
		-- sign priorities for each type of mark - builtin marks, uppercase marks, lowercase
		-- marks, and bookmarks.
		-- can be either a table with all/none of the keys, or a single number, in which case
		-- the priority applies to all marks.
		-- default 10.
		sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
		-- disables mark tracking for specific filetypes. default {}
		excluded_filetypes = {},
		-- disables mark tracking for specific buftypes. default {}
		excluded_buftypes = {},
		-- marks.nvim allows you to configure up to 10 bookmark groups, each with its own
		-- sign/virttext. Bookmarks can be used to group together positions and quickly move
		-- across multiple buffers. default sign is '!@#$%^&*()' (from 0 to 9), and
		-- default virt_text is "".
		bookmark_0 = {
			sign = "⚑",
			virt_text = "hello world",
			-- explicitly prompt for a virtual line annotation when setting a bookmark from this group.
			-- defaults to false.
			annotate = false,
		},
		mappings = {},
	},
	config = function(_, opts)
		require("marks").setup(opts)

		-- Toggle jump for uppercase marks: jump to mark, or jump back if already there
		local origin = {}
		for i = 65, 90 do -- A-Z
			local mark = string.char(i)
			vim.keymap.set("n", "'" .. mark, function()
				local cur_buf = vim.api.nvim_get_current_buf()
				local cur_pos = vim.api.nvim_win_get_cursor(0)
				local mark_pos = vim.api.nvim_get_mark(mark, {})
				-- mark_pos = {row, col, bufnr, buffername}
				local mark_row = mark_pos[1]
				local mark_file = mark_pos[4]

				if mark_row == 0 then
					return
				end

				-- Resolve the mark's buffer by filename
				local mark_buf = vim.fn.bufnr(mark_file)

				-- Check if we're at the mark's location (same buffer and line)
				if mark_buf == cur_buf and mark_row == cur_pos[1] and origin[mark] then
					-- Jump back to origin
					local o = origin[mark]
					vim.cmd("buffer " .. o.buf)
					vim.api.nvim_win_set_cursor(0, { o.line, o.col })
					origin[mark] = nil
				else
					-- Save origin and jump to mark
					origin[mark] = { buf = cur_buf, line = cur_pos[1], col = cur_pos[2] }
					vim.cmd("'" .. mark)
				end
			end, { desc = "Toggle jump to mark " .. mark })
		end
	end,
}
