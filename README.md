# Tmuxscope - Telescope Tmux Session Manager

A Telescope extension for managing tmux sessions directly from Neovim, inspired by [tmux-sessionizer](https://github.com/ThePrimeagen/tmux-sessionizer)

## Requirements
- Ideally inside a tmux session
- [tmux](https://github.com/tmux/tmux) - Must be installed and available in PATH
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Required dependency
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Required by telescope 

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'maskdotdev/tmuxscope.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('telescope').load_extension('tmuxscope')
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'maskdotdev/tmuxscope.nvim',
  requires = {
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('telescope').load_extension('tmuxscope')
  end,
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'maskdotdev/tmuxscope.nvim'
```

Then in your `init.lua`:
```lua
require('telescope').load_extension('tmuxscope')
```

## Features

- List and switch between existing tmux sessions
- Create new tmux sessions from predefined directories
- Delete tmux sessions
- Works both inside and outside tmux

## Usage

### List and Switch Sessions

```vim
:Telescope tmuxscope sessions
```

This will show all existing tmux sessions with:
- Session name
- Number of windows
- Attachment status

**Keybindings:**
- `<Enter>`: Switch to selected session
- `<C-x>`: Delete selected session

### Create New Session

```vim
:Telescope tmuxscope new_session
```

This will show directories from your configured search paths where you can create new tmux sessions.

## Configuration

Add to your telescope setup:

```lua
require('telescope').setup {
  extensions = {
    tmuxscope = {
      search_paths = {
        '~/projects',
        '~/work',
        '~/dev',
        '~/.config',
        '~/Documents',
      },
      tmux_command = 'tmux', -- Optional: specify tmux command path
    },
  },
}

-- Load the extension
require('telescope').load_extension('tmuxscope')
```

## Keymaps

You can set up convenient keymaps:

```lua
vim.keymap.set('n', '<leader>ts', function()
  require('telescope').extensions.tmuxscope.sessions()
end, { desc = '[T]mux [S]essions' })

vim.keymap.set('n', '<leader>tc', function()
  require('telescope').extensions.tmuxscope.new_session()
end, { desc = '[T]mux [C]reate New Session' })
```

