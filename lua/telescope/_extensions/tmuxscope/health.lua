local M = {}

-- Helper function to execute shell commands
local function execute_command(cmd)
  local handle = io.popen(cmd .. " 2>/dev/null")
  if not handle then
    return nil
  end
  local result = handle:read("*a")
  handle:close()
  return result
end

-- Check if tmux is installed and accessible
local function check_tmux_installation()
  local tmux_version = execute_command("tmux -V")
  if tmux_version then
    vim.health.ok("tmux is installed: " .. tmux_version:gsub("\n", ""))
    return true
  else
    vim.health.error("tmux is not installed or not in PATH", {
      "Install tmux using your package manager:",
      "  - Ubuntu/Debian: sudo apt install tmux", 
      "  - macOS: brew install tmux",
      "  - Arch: sudo pacman -S tmux"
    })
    return false
  end
end

-- Check if telescope is available
local function check_telescope()
  local ok, telescope = pcall(require, "telescope")
  if ok then
    vim.health.ok("telescope.nvim is available")
    return true
  else
    vim.health.error("telescope.nvim is not installed", {
      "Install telescope.nvim: https://github.com/nvim-telescope/telescope.nvim"
    })
    return false
  end
end

-- Check if we can access tmux sessions
local function check_tmux_access()
  local sessions_result = execute_command("tmux list-sessions -F '#{session_name}'")
  if sessions_result ~= nil then
    local session_count = 0
    for _ in sessions_result:gmatch("[^\r\n]+") do
      session_count = session_count + 1
    end
    
    if session_count > 0 then
      vim.health.ok(string.format("Found %d tmux session(s)", session_count))
    else
      vim.health.info("No tmux sessions currently running")
    end
    return true
  else
    vim.health.warn("Cannot access tmux sessions", {
      "This might be normal if tmux server is not running",
      "You can start tmux by running: tmux new-session"
    })
    return false
  end
end

-- Check search paths configuration
local function check_search_paths()
  -- Get the current configuration
  local ok, tmuxscope = pcall(require, "telescope._extensions.tmuxscope")
  if not ok then
    vim.health.error("Cannot load tmuxscope extension", {
      "Make sure the plugin is properly installed"
    })
    return false
  end

  -- Default search paths that should be checked
  local default_paths = {
    "~/projects",
    "~/work", 
    "~/dev",
    "~/.config",
    "~/Documents"
  }

  local valid_paths = 0
  local total_paths = #default_paths

  for _, path in ipairs(default_paths) do
    local expanded_path = vim.fn.expand(path)
    if vim.fn.isdirectory(expanded_path) == 1 then
      valid_paths = valid_paths + 1
    end
  end

  if valid_paths > 0 then
    vim.health.ok(string.format("%d/%d default search paths exist", valid_paths, total_paths))
  else
    vim.health.warn("No default search paths exist", {
      "Consider creating some project directories:",
      "  mkdir -p ~/projects ~/work ~/dev"
    })
  end

  return valid_paths > 0
end

-- Check if we're in a tmux session
local function check_tmux_environment()
  local tmux_var = os.getenv("TMUX")
  if tmux_var then
    vim.health.info("Currently running inside tmux session")
    vim.health.info("Session switching will work directly")
  else
    vim.health.info("Not running inside tmux")
    vim.health.info("Session commands will provide attach instructions")
  end
end

-- Check required Neovim features
local function check_neovim_features()
  if vim.fn.has("nvim-0.7") == 1 then
    vim.health.ok("Neovim version is compatible (0.7+)")
  else
    vim.health.error("Neovim 0.7+ is required", {
      "Please upgrade your Neovim installation"
    })
    return false
  end

  -- Check for ui.input (used for directory name input)
  if vim.ui and vim.ui.input then
    vim.health.ok("vim.ui.input is available")
  else
    vim.health.warn("vim.ui.input not available", {
      "Some features may not work properly",
      "Consider installing a UI plugin like dressing.nvim"
    })
  end

  return true
end

-- Main health check function
M.check = function()
  vim.health.start("tmuxscope health check")

  -- Core dependency checks
  local tmux_ok = check_tmux_installation()
  local telescope_ok = check_telescope()
  local nvim_ok = check_neovim_features()

  if not (tmux_ok and telescope_ok and nvim_ok) then
    vim.health.error("Core dependencies missing", {
      "Fix the above issues before using tmuxscope"
    })
    return
  end

  -- Feature checks
  check_tmux_access()
  check_tmux_environment() 
  check_search_paths()

  vim.health.info("tmuxscope is ready to use!")
  vim.health.info("Available commands:")
  vim.health.info("  :Telescope tmuxscope sessions")
  vim.health.info("  :Telescope tmuxscope new_session") 
  vim.health.info("  :Telescope tmuxscope create_dir_session")
end

return M 