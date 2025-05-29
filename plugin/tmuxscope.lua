-- Auto-load tmuxscope extension for telescope
-- This file ensures the extension is loaded when telescope is available

if vim.fn.has("nvim-0.7") == 0 then
	vim.api.nvim_err_writeln("tmuxscope.nvim requires Neovim >= 0.7")
	return
end

-- Auto-load the extension when telescope loads
vim.api.nvim_create_autocmd("User", {
	pattern = "TelescopeLoaded",
	callback = function()
		pcall(require("telescope").load_extension, "tmuxscope")
	end,
})

-- Automatically load tmuxscope extension when telescope is available
if pcall(require, "telescope") then
	require("telescope").load_extension("tmuxscope")
end
