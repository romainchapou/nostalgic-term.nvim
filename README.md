# nostalgic-term.nvim

An attempt at improving Neovim's integrated terminal by mimicking Vim's behaviour.

![](https://github.com/romainchapou/readme-files/blob/17c3c85f08f6a020028f9c589ac882ed1f9fe6ce/nostalgic-term-demo.gif)

## Features

- simulates a mode (terminal or normal) per terminal buffer, as in Vim.
- define your window movement mappings only once for terminal mode and normal mode if desired.
- configurable to be as close as Vim as possible.

Bonus feature: you can set any mapping for window movements in terminal mode without interfering with plugins using terminal buffers (for example [fzf-lua](https://github.com/ibhagwan/fzf-lua) that can use `<c-j>` and `<c-k>` to jump to the next/previous entry)


## Motivations

The terminal implementation is probably the only feature I think Vim has done better than Neovim.

Most notably, in Vim, the terminal buffers are by default in terminal mode (the insert mode of the terminal) and you can switch windows from this terminal mode, or from normal mode. In Neovim, you can only switch windows from a terminal window by first going to normal mode. To be more precise, in Vim each terminal buffer has its local mode, while in Neovim the mode is shared between all the buffers.

This can be mostly solved by using something like:

```vim
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" Always launch insert mode when entering a terminal buffer 
autocmd BufEnter * if &buftype == 'terminal' | :startinsert | endif
```

But this is far from perfect as, when you switch a terminal buffer to normal mode, you probably want it to stay in normal mode until you switch back manually to terminal mode.

Another unrelated problem I've had with terminal mode mappings is that they may override some mappings in plugins using a terminal buffer, like [fzf-lua](https://github.com/ibhagwan/fzf-lua) for `<c-j>` and `<c-k>`.

nostalgic-term should solve those problems and simplify your configuration.


## Installation

Use your favourite plugin manager and call the `setup` function (lua):

```
require('nostalgic-term').setup({})
```

See below for some optional configuration.


## Configuration

Default configuration (lua):

```lua
require('nostalgic-term').setup({
  mappings = {}, -- list of mappings in the form {lhs, rhs} with
                 -- * lhs: a string representing a key combination to bind to in terminal
                 --        mode, for example: '<c-h>' or '<c-n>'
                 -- * rhs: a string representing a correct :wincmd argument,
                 --        for example: 'h' or 'gt'
  start_in_insert_mode = true, -- start new terminals in insert mode by default, as in Vim
  add_normal_mode_mappings = false, -- if true, also add mappings in normal mode (with nore)
  add_vim_ctrl_w = false, -- if true, add ctrl-w as a launcher of window commands also in
                          -- the terminal, as in Vim
  enabled_filetypes = {}, -- a list of the filetypes for custom terminal buffers where mode
                          -- saving and mappings should be applied. This is useful for
                          -- compatibility with other terminal plugins, see the README.
})
```

A configuration example (mine) that sets window movement mappings (lua):

```lua
require('nostalgic-term').setup({
  mappings = {
    {'<c-h>', 'h'},
    {'<c-j>', 'j'},
    {'<c-k>', 'k'},
    {'<c-l>', 'l'},
  },
  add_normal_mode_mappings = true,
})
```

## Compatibility with other plugins

To use nostalgic-term in conjunction with a plugin such as [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim) that provides a custom terminal, you should add that plugin's terminal buffer filetype to the `enabled_filetypes` option. There may also be some settings to use in the other plugin.


### For [toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim)

Add `"toggleterm"` to nostalgic-term's `enabled_filetypes` option (lua):

```lua
require('nostalgic-term').setup{
  -- ... your other settings ...
  enabled_filetypes = {"toggleterm"},
}
```

You should then set toggleterm's `start_in_insert` option to false to let nostalgic-term handle the insert/normal mode switch (lua):

```lua
require('toggleterm').setup{
  -- ... your other settings ...
  start_in_insert = false,
}
```


### For other plugins

If the plugin isn't directly compatible with nostalgic-term, find the plugin's filetype (using for example `:set ft?` in the terminal buffer) and add it to the `enabled_filetypes` option. If you still have some problems, you can create an issue in this repo.


## Known limitations

- resizing a window while the focus is on a terminal window in terminal mode will put that terminal window in normal mode.
- correct cursor positions can't be guaranteed if switching from multiple windows containing the same terminal buffer in normal mode.
