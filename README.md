# vim-term-mimic.nvim

Mimic the behaviour of Vim's terminal in Neovim.

## Features

- simulates a mode (terminal or normal) per terminal buffer, as in Vim.
- define your window movement mappings only once for terminal mode and normal mode if desired.
- configurable to be as close as Vim as possible.

Bonus feature: you can set any mapping for window movements in terminal mode without interfering with plugins using terminal buffers (for example [fzf-lua](https://github.com/ibhagwan/fzf-lua) that can use `<c-j>` and `<c-k>` to jump to the next/previous entry)


## Motivations

The terminal implementation is probably the only feature I think Vim has done better than Neovim.

Most notably, in Vim, the terminal buffers are by default in terminal mode (the insert mode of the terminal) and you can switch windows from this terminal mode, or from normal mode. In Neovim, you can only switch windows from a terminal window by first going to normal mode.

This can be mostly solved by using something like:

```vim
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" Always launch insert mode when entering a terminal buffer 
autocmd BufEnter * if &buftype == 'terminal' | :startinsert | endif
```

But this is limited as, when you switch a terminal buffer to normal mode, you probably want it to stay in normal mode until you switch back manually to insert mode. Also, those simple tnoremaps may override some mappings in plugins using a terminal buffer, like [fzf-lua](https://github.com/ibhagwan/fzf-lua) for `<c-j>` and `<c-k>`.

vim-term-mimic should solve those problems and simplify your configuration.


## Installation

Use your favourite plugin manager and call the `setup` function as shown below.


## Configuration

Default configuration (lua):

```lua
require('vim-term-mimic').setup({
  mappings = {}, -- list of mappings in the form {lhs, rhs} with
                 -- * lhs: a string representing a key combination to bind to in terminal
                 --        mode, for example: '<c-h>' or '<c-n>'
                 -- * rhs: a string representing a correct :wincmd argument,
                 --        for example: 'h' or 'gt'
  start_in_insert_mode = true, -- start new terminals in insert mode by default, as in Vim
  add_normal_mode_mappings = false, -- if true, also add mappings in normal mode (with nore)
  add_vim_ctrl_w = false, -- if true, add ctrl-w as a launcher of window commands also in
                          -- the terminal, as in Vim
})
```

A configuration example (mine) with mappings (lua):

```lua
require('vim-term-mimic').setup({
  mappings = {
    {'<c-h>', 'h'},
    {'<c-j>', 'j'},
    {'<c-k>', 'k'},
    {'<c-l>', 'l'},
    -- less common mappings
    {'<c-n>', 'gt'},
    {'<c-b>', 'gT'},
  },
  add_normal_mode_mappings = true,
})
```


## Limitations

- correct cursor positions can't be guaranteed if switching from multiple windows containing the same terminal buffer in normal mode.
- switching from a terminal to another window using the mouse will count as setting the terminal to normal mode.
