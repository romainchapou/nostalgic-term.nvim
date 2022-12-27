-- NOTE this will probably not behave properly if
-- * you are switching from multiple windows containing the same terminal buffer
-- * switch windows using another mean than the mappings given in the setup function, including the mouse

local M = { monitored_terminals = {} }

local modes = require("terminal_insert_switch.internal").modes

local default_options = {
  mappings = {},
  add_normal_mode_mappings = false,
}

function M.setup(custom_options)
  local internal = require("terminal_insert_switch.internal")

  local options = vim.tbl_deep_extend("force", default_options, custom_options)

  if not internal.are_custom_options_valid(options) then return end

  local autocmd_group = vim.api.nvim_create_augroup("terminal_switch_autocmds", {})

  vim.api.nvim_create_autocmd({"TermOpen"}, {
    group = autocmd_group,

    callback = function()
      -- @Cleanup: call to is_regular_terminal() maybe useless/false
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

      vim.api.nvim_create_autocmd({"BufDelete"}, {
        group = autocmd_group,
        buffer = buf_nb,
        callback = internal.remove_from_monitored_terminals(M.monitored_terminals, buf_nb)
      })

      vim.api.nvim_create_autocmd({"BufEnter"}, {
        group = autocmd_group,
        buffer = buf_nb,
        callback = internal.switch_to_correct_mode_and_update(M.monitored_terminals, buf_nb)
      })

      vim.api.nvim_create_autocmd({"BufLeave"}, {
        group = autocmd_group,
        buffer = buf_nb,
        callback = internal.save_cursor_position(M.monitored_terminals, buf_nb)
      })
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
