# :cyclone: GitLinks
Copy file/blame git links directly from neovim.

## Features
Copy and Open remote file and blame links directly from neovim. All exposed commands can be used with or without a visual range; the links will be generated accordingly. The module will try to not generate or open links for files/branches/changes that don't exist on the remote, and display an error instead.

Inspired by [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive) and [ruifm/gitlinker.nvim](https://github.com/ruifm/gitlinker.nvim).

### Supported services
- GitHub
- GitLab

## Requirements
- git
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for internal functions

## Installation
### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
return {
  'liouk/gitlinks.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('gitlinks').setup()
  end,
}
```

## Configuration
No configuration is necessary for this plugin.

## Usage
The plugin exposes the following commands:
- `:GitlinkFileCopy`: copy file link
- `:GitlinkFileOpen`: open file link on system browser
- `:GitlinkBlameCopy`: copy file blame link
- `:GitlinkBlameOpen`: open file blame link on system browser

All commands support visual ranges.
