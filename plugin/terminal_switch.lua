-- NOTE: will not work for mouse clicks in a terminal window (will always return to normal mode, but i guess that's ok)

-- a table mapping a buffer id to the mode (1 for insert mode, 0 for normal mode)
-- TODO badly named, should maybe be TermWindowsFutureState or TermWindowsNextState
TermWindowsState = {}

local modes = { insert = 1, normal = 0 }

local autocmd_group = vim.api.nvim_create_augroup("terminal_switch_autocmds", {})

local function is_terminal()
  return vim.api.nvim_get_option_value("buftype", {scope = "local"}) == 'terminal'
end

-- assumes is_terminal() true
local function is_regular_terminal()
  return vim.api.nvim_get_option_value("ft", {scope = "local"}) == ''
end

local function is_cur_window_floating()
  return vim.api.nvim_win_get_config(0).zindex
end

vim.api.nvim_create_autocmd({"BufEnter"}, {
  group = autocmd_group,

  callback = function()
    if is_terminal() and is_regular_terminal() then
      local buf_nb = vim.api.nvim_call_function("bufnr", {})

      -- Not previously seen buffer => this is a new buffer, set it to insert mode
      if not TermWindowsState[buf_nb] then
        TermWindowsState[buf_nb] = modes.normal
      else
        if TermWindowsState[buf_nb] == modes.insert then
          vim.api.nvim_command("startinsert")
        end

        TermWindowsState[buf_nb] = modes.normal
      end
    end
  end
})

local function switch_windows(win_cmd)
  return function()
    -- if not is_regular_terminal() then return end

    local buf_nb = vim.api.nvim_call_function("bufnr", {})

    TermWindowsState[buf_nb] = modes.insert

    vim.api.nvim_command("wincmd " .. win_cmd)
  end
end

vim.api.nvim_create_autocmd({"TermOpen"}, {
  group = autocmd_group,

  callback = function()
    -- @Cleanup: call to is_regular_terminal() maybe useless/false
    if is_terminal() and is_regular_terminal() and not is_cur_window_floating() then
      vim.keymap.set('t', '<c-h>', switch_windows('h'), {buffer = true})
      vim.keymap.set('t', '<c-l>', switch_windows('l'), {buffer = true})
      vim.keymap.set('t', '<c-k>', switch_windows('k'), {buffer = true})
      vim.keymap.set('t', '<c-j>', switch_windows('j'), {buffer = true})
    end
  end
})
