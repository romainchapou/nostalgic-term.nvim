-- This plugin's implementation relies on the monitored_terminals table to
-- simulate being able to switch windows from terminal mode (the insert mode
-- for terminal buffers).
--
-- For every opened terminal buffer, we store in this table the mode (normal or
-- insert) it should be in when we switch back to it. This is done by using
-- auto commands and being careful about the timing of the operations. We also
-- store the cursor position for terminals in normal mode to deal with edge
-- cases.

local M = { monitored_terminals = {} }

local default_options = {
  mappings = {}, -- list of mappings in the form {lhs, rhs} with
                 -- * lhs: a string representing a key combination to bind to in terminal
                 --        mode, for example: '<c-h>' or '<c-n>'
                 -- * rhs: a string representing a correct :wincmd argument,
                 --        for example: 'h' or 'gt'
  start_in_insert_mode = true, -- start new terminals in insert mode by default, as in Vim
  add_normal_mode_mappings = false, -- if true, also add mappings in normal mode (with nore)
  add_vim_ctrl_w = false, -- if true, add ctrl-w as a launcher of window commands also in
                          -- the terminal, as in Vim
}

function M.setup(custom_options)
  local internal = require("vim-term-mimic.internal")

  local options = vim.tbl_deep_extend("force", default_options, custom_options)

  local mappings_are_valid = internal.are_custom_mappings_valid(options)

  local autocmd_group = vim.api.nvim_create_augroup("vim-term-mimic-autocmds", {})

  vim.api.nvim_create_autocmd({"TermOpen"}, {
    group = autocmd_group,

    callback = function()
      -- Using vim.schedule here so custom terminals (meaning terminal buffers
      -- used in plugins) can have the time to set their 'filetype' option and
      -- be identified by is_regular_terminal.
      vim.schedule(function()
        if not (internal.is_regular_terminal() and not internal.is_cur_window_floating()) then
          -- Avoid the application of our mappings and mode saving for terminal
          -- buffers used by plugins
          return
        end

        local buf_nb = vim.api.nvim_get_current_buf()

        if options.start_in_insert_mode then
          vim.api.nvim_command("startinsert")
        end

        if mappings_are_valid then
          for _, mapping in pairs(options.mappings) do
            vim.keymap.set('t', mapping[1], internal.switch_windows_fn(mapping[2]), {buffer = true})
          end
        end

        if options.add_vim_ctrl_w then
          vim.keymap.set('t', '<c-w>', internal.vim_terminal_ctrl_w_fn(buf_nb), {buffer = true})
        end

        M.monitored_terminals[buf_nb] = { curs_pos_valid = true }

        if vim.api.nvim_get_current_buf() == buf_nb and vim.api.nvim_get_mode().mode ~= 'nt' then
          M.monitored_terminals[buf_nb].mode = internal.modes.insert
        else
          M.monitored_terminals[buf_nb].mode = internal.modes.normal
        end

        local function register_buffer_autocmd(autocmd_event, callback)
          vim.api.nvim_create_autocmd({autocmd_event}, {
            group = autocmd_group,
            buffer = buf_nb,
            callback = callback(M.monitored_terminals, buf_nb)
          })
        end

        register_buffer_autocmd("TermEnter", internal.set_buf_state_to_insert)
        register_buffer_autocmd("TermLeave", internal.set_buf_state_to_normal)
        register_buffer_autocmd("BufEnter", internal.switch_to_correct_mode)
        register_buffer_autocmd("BufLeave", internal.save_cursor_position)
        register_buffer_autocmd("BufDelete", internal.remove_from_monitored_terminals)
      end)
    end
  })

  if options.add_normal_mode_mappings and mappings_are_valid then
    for _, mapping in pairs(options.mappings) do
      vim.keymap.set('n', mapping[1], internal.switch_windows_fn(mapping[2]))
    end
  end
end

return M
