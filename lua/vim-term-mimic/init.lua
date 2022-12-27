-- This plugin's implementation relies on the monitored_terminals table to
-- simulate being able to switch windows from terminal mode (the insert mode
-- for terminal buffers).
--
-- For every opened terminal buffer, we store in this table the mode (normal or
-- insert) it should be in **when we switch back to it**. When leaving the
-- terminal buffer from one of the user defined terminal mode mapping, we set
-- the mode to switch back to to insert. When entering the terminal buffer, we
-- apply the correct mode according to the table and set the mode to normal (as
-- if the user goes to normal mode before leaving the terminal, we want to
-- switch to normal mode when the user gets back to this terminal). We also
-- store the cursor position to deal with edge cases.
--
-- See the README for the limitations.

local M = { monitored_terminals = {} }

local default_options = {
  mappings = {}, -- list of mappings in the form {lhs, rhs} with
                 -- * lhs: a string representing a key combination to bind to in terminal
                 --        mode, for example: '<c-h>' or '<c-n>'
                 -- * rhs: a string representing a correct :wincd argument,
                 --        for example: 'h' or 'gt'
  start_in_insert_mode = true, -- start new terminals in insert mode by default, as in Vim
  add_normal_mode_mappings = false, -- if true, also add mappings in normal mode (with nore)
  add_vim_ctrl_w = false, -- if true, add ctrl-w as a launcher of window commands also in
                          -- the terminal, as in Vim
}

function M.setup(custom_options)
  local internal = require("vim-term-mimic.internal")

  local options = vim.tbl_deep_extend("force", default_options, custom_options)

  if not internal.are_custom_options_valid(options) then return end

  local autocmd_group = vim.api.nvim_create_augroup("vim-term-mimic-autocmds", {})

  vim.api.nvim_create_autocmd({"TermOpen"}, {
    group = autocmd_group,

    callback = function()
      -- Using vim.schedule here so custom terminals (meaning terminal buffers
      -- used in plugins) can have the time to set their 'filetype' option and
      -- be identified by is_regular_terminal.
      vim.schedule(function()
        if not (internal.is_regular_terminal() and not internal.is_cur_window_floating()) then
          return
        end

        if options.start_in_insert_mode then
          vim.api.nvim_command("startinsert")
        end

        local buf_nb = internal.get_cur_buf_nb()
        M.monitored_terminals[buf_nb] = { mode = internal.modes.normal }

        for _, mapping in pairs(options.mappings) do
          vim.keymap.set('t', mapping[1],
                         internal.switch_windows_fn(mapping[2], 't', M.monitored_terminals, buf_nb),
                         {buffer = true})
        end

        if options.add_vim_ctrl_w then
          vim.keymap.set('t', '<c-w>', internal.vim_terminal_ctrl_w_fn(M.monitored_terminals, buf_nb),
                         {buffer = true})
        end

        local function register_buffer_autocmd(autocmd_event, callback)
          vim.api.nvim_create_autocmd({autocmd_event}, {
            group = autocmd_group,
            buffer = buf_nb,
            callback = callback(M.monitored_terminals, buf_nb)
          })
        end

        register_buffer_autocmd("BufEnter", internal.switch_to_correct_mode_and_update)
        register_buffer_autocmd("BufLeave", internal.save_cursor_position)
        register_buffer_autocmd("BufDelete", internal.remove_from_monitored_terminals)
      end)
    end
  })

  if options.add_normal_mode_mappings then
    for _, mapping in pairs(options.mappings) do
      vim.keymap.set('n', mapping[1], internal.switch_windows_fn(mapping[2], 'n', M.monitored_terminals))
    end
  end
end

return M
