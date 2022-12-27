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

local modes = require("term-insert-switch.internal").modes

local default_options = {
  mappings = {},
  add_normal_mode_mappings = false,
}

function M.setup(custom_options)
  local internal = require("term-insert-switch.internal")

  local options = vim.tbl_deep_extend("force", default_options, custom_options)

  if not internal.are_custom_options_valid(options) then return end

  local autocmd_group = vim.api.nvim_create_augroup("term-insert-switch-autocmds", {})

  vim.api.nvim_create_autocmd({"TermOpen"}, {
    group = autocmd_group,

    callback = function()
      -- Using vim.schedule here so custom terminals (meaning termina buffers
      -- used in plugins) can have the time to set their 'filetype' option and
      -- be identified by is_regular_terminal.
      vim.schedule(function()
        if not (internal.is_regular_terminal() and not internal.is_cur_window_floating()) then
          return
        end

        local buf_nb = vim.api.nvim_call_function("bufnr", {})
        M.monitored_terminals[buf_nb] = { mode = modes.normal }

        for _, mapping in pairs(options.mappings) do
          vim.keymap.set('t', mapping[1],
                         internal.switch_windows_fn(mapping[2], 't', M.monitored_terminals, buf_nb),
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
    -- also add the users mapping in normal mode
    for _, mapping in pairs(options.mappings) do
      vim.keymap.set('n', mapping[1], internal.switch_windows_fn(mapping[2], 'n', M.monitored_terminals))
    end
  end
end

return M
