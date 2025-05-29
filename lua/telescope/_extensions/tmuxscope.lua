local telescope = require("telescope")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local M = {}

-- Default configuration
local default_config = {
	-- Paths to search for new session creation
	search_paths = {
		"~/projects",
		"~/work",
		"~/dev",
		"~/.config",
		"~/Documents",
	},
	-- Additional tmux options
	tmux_command = "tmux",
}

-- Current configuration (will be merged with user config)
M.config = vim.deepcopy(default_config)

-- Helper function to execute shell commands
local function execute_command(cmd)
	local handle = io.popen(cmd)
	if not handle then
		return nil
	end
	local result = handle:read("*a")
	handle:close()
	return result
end

-- Get list of tmux sessions with additional info
local function get_tmux_sessions()
	local sessions = {}
	local cmd = M.config.tmux_command
		.. ' list-sessions -F "#{session_name}:#{session_windows}:#{session_attached}" 2>/dev/null'
	local result = execute_command(cmd)

	if result then
		local index = 1
		for line in result:gmatch("[^\r\n]+") do
			local session_name, windows, attached = line:match("([^:]+):([^:]+):([^:]+)")
			if session_name then
				table.insert(sessions, {
					name = session_name,
					windows = windows,
					attached = attached == "1",
					index = index,
				})
				index = index + 1
			end
		end
	end

	return sessions
end

-- Check if we're inside tmux
local function is_in_tmux()
	return os.getenv("TMUX") ~= nil
end

-- Switch to or attach to a tmux session
local function switch_to_session(session_name)
	local cmd
	if is_in_tmux() then
		cmd = M.config.tmux_command .. ' switch -t "' .. session_name .. '"'
		-- Execute the command
		vim.fn.system(cmd)
		if vim.v.shell_error == 0 then
			print("Switched to session: " .. session_name)
		else
			print("Failed to switch to session: " .. session_name)
		end
	else
		-- When outside tmux, we can't directly attach from within Neovim
		-- Instead, provide instructions to the user
		print('Session "' .. session_name .. '" is ready!')
		print('To attach to it, run: tmux attach-session -t "' .. session_name .. '"')
		print("Or exit Neovim and run the command above.")

		-- Optionally, copy the command to clipboard if available
		local attach_cmd = 'tmux attach-session -t "' .. session_name .. '"'
		if vim.fn.has("clipboard") == 1 then
			vim.fn.setreg("+", attach_cmd)
			print("Command copied to clipboard!")
		end
	end
end

-- Delete a tmux session
local function delete_session(session_name)
	local cmd = M.config.tmux_command .. ' kill-session -t "' .. session_name .. '"'
	local result = vim.fn.system(cmd)
	if vim.v.shell_error == 0 then
		print("Deleted session: " .. session_name)
	else
		print("Failed to delete session: " .. session_name)
	end
end

-- Create a new tmux session
local function create_session(session_name, path)
	local cmd = M.config.tmux_command .. ' new -d -s "' .. session_name .. '" -c "' .. path .. '"'
	local result = vim.fn.system(cmd)
	if vim.v.shell_error == 0 then
		print("Created session: " .. session_name .. " in " .. path)
		switch_to_session(session_name)
	else
		print("Failed to create session: " .. session_name)
		print("Error: " .. result)
	end
end

-- Get directories from configured paths
local function get_directories()
	local directories = {}

	for _, search_path in ipairs(M.config.search_paths) do
		-- Expand tilde
		local expanded_path = vim.fn.expand(search_path)

		-- Check if path exists
		if vim.fn.isdirectory(expanded_path) == 1 then
			-- Get subdirectories
			local cmd = 'find "' .. expanded_path .. '" -maxdepth 2 -type d 2>/dev/null'
			local result = execute_command(cmd)

			if result then
				for dir in result:gmatch("[^\r\n]+") do
					-- Skip hidden directories and the search path itself
					local basename = vim.fn.fnamemodify(dir, ":t")
					if not basename:match("^%.") and dir ~= expanded_path then
						table.insert(directories, dir)
					end
				end
			end
		end
	end

	return directories
end

-- Main sessions picker
M.sessions = function(opts)
	opts = opts or {}

	local sessions = get_tmux_sessions()

	if #sessions == 0 then
		print("No tmux sessions found")
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Tmux Sessions",
			finder = finders.new_table({
				results = sessions,
				entry_maker = function(entry)
					local display = string.format(
						"%d. %s (%s windows)%s",
						entry.index,
						entry.name,
						entry.windows,
						entry.attached and " [attached]" or ""
					)
					return {
						value = entry.name,
						display = display,
						ordinal = string.format("%02d", entry.index) .. " " .. entry.name .. " " .. display,
						index = entry.index, -- Keep the index for sorting
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			default_selection_index = 1,
			attach_mappings = function(prompt_bufnr, map)
				-- Default action: switch to session
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						switch_to_session(selection.value)
					end
				end)

				-- Delete session with <C-x>
				map("i", "<C-x>", function()
					local selection = action_state.get_selected_entry()
					if selection then
						actions.close(prompt_bufnr)
						delete_session(selection.value)
						-- Refresh the picker
						vim.schedule(function()
							M.sessions(opts)
						end)
					end
				end)

				map("n", "<C-x>", function()
					local selection = action_state.get_selected_entry()
					if selection then
						actions.close(prompt_bufnr)
						delete_session(selection.value)
						-- Refresh the picker
						vim.schedule(function()
							M.sessions(opts)
						end)
					end
				end)

				return true
			end,
		})
		:find()
end

-- New session picker
M.new_session = function(opts)
	opts = opts or {}

	local directories = get_directories()

	if #directories == 0 then
		print("No directories found in configured search paths: " .. table.concat(M.config.search_paths, ", "))
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Create New Tmux Session",
			finder = finders.new_table({
				results = directories,
				entry_maker = function(entry)
					local display_name = vim.fn.fnamemodify(entry, ":t")
						.. " ("
						.. vim.fn.fnamemodify(entry, ":h")
						.. ")"
					return {
						value = entry,
						display = display_name,
						ordinal = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						local path = selection.value
						local session_name = vim.fn.fnamemodify(path, ":t")

						-- Check if session already exists
						local existing_sessions = get_tmux_sessions()
						for _, existing in ipairs(existing_sessions) do
							if existing.name == session_name then
								print('Session "' .. session_name .. '" already exists')
								switch_to_session(session_name)
								return
							end
						end

						create_session(session_name, path)
					end
				end)

				return true
			end,
		})
		:find()
end

-- Helper function to sanitize directory names
local function sanitize_directory_name(name)
	-- Replace spaces and special characters with hyphens
	-- Remove multiple consecutive hyphens and trim
	return name:gsub("[^%w_-]", "-"):gsub("%-+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
end

-- Create a new directory and tmux session
local function create_directory_and_session(base_path, directory_name)
	local sanitized_name = sanitize_directory_name(directory_name)
	if sanitized_name == "" then
		print("Invalid directory name")
		return
	end

	local full_path = base_path .. "/" .. sanitized_name

	-- Check if directory already exists
	if vim.fn.isdirectory(full_path) == 1 then
		print("Directory already exists: " .. full_path)
		local session_name = sanitized_name

		-- Check if session already exists
		local existing_sessions = get_tmux_sessions()
		for _, existing in ipairs(existing_sessions) do
			if existing.name == session_name then
				print('Session "' .. session_name .. '" already exists')
				switch_to_session(session_name)
				return
			end
		end

		create_session(session_name, full_path)
		return
	end

	-- Create directory
	local mkdir_cmd = 'mkdir -p "' .. full_path .. '"'
	local result = vim.fn.system(mkdir_cmd)

	if vim.v.shell_error == 0 then
		print("Created directory: " .. full_path)
		create_session(sanitized_name, full_path)
	else
		print("Failed to create directory: " .. full_path)
		print("Error: " .. result)
	end
end

-- Create directory and session picker
M.create_dir_session = function(opts)
	opts = opts or {}

	local base_paths = {}
	for _, search_path in ipairs(M.config.search_paths) do
		local expanded_path = vim.fn.expand(search_path)
		if vim.fn.isdirectory(expanded_path) == 1 then
			table.insert(base_paths, expanded_path)
		end
	end

	if #base_paths == 0 then
		print(
			"No valid base directories found in configured search paths: " .. table.concat(M.config.search_paths, ", ")
		)
		return
	end

	pickers
		.new(opts, {
			prompt_title = "Select Base Directory for New Project",
			finder = finders.new_table({
				results = base_paths,
				entry_maker = function(entry)
					local display_name = vim.fn.fnamemodify(entry, ":t") .. " (" .. entry .. ")"
					return {
						value = entry,
						display = display_name,
						ordinal = entry,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						local base_path = selection.value

						-- Prompt for directory name
						vim.ui.input({
							prompt = "Enter new directory name: ",
						}, function(directory_name)
							if directory_name and directory_name ~= "" then
								create_directory_and_session(base_path, directory_name)
							else
								print("Directory creation cancelled")
							end
						end)
					end
				end)

				return true
			end,
		})
		:find()
end

-- Setup function for configuration
M.setup = function(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)
end

return telescope.register_extension({
	setup = M.setup,
	exports = {
		sessions = M.sessions,
		new_session = M.new_session,
		create_dir_session = M.create_dir_session,
	},
})
