-- NOTE this will probably not behave properly if
-- * you are switching from multiple windows containing the same terminal buffer
-- * switch windows using another mean than the mappings given in the setup function, including the mouse

local M = { monitored_terminals = {} }

local modes = { insert = 1, normal = 0 }

-- assumes it is running from a terminal buffer
local function is_regular_terminal()
  return vim.api.nvim_get_option_value("ft", {scope = "local"}) == ''
end

local function is_cur_window_floating()
  return vim.api.nvim_win_get_config(0).zindex
end

-- NOTE: this doesn't support doing ':Xwincd win_cmd', with X a number
local function switch_windows_fn(win_cmd, mode)
  if mode == 't' then
    return function()
      local buf_nb = vim.api.nvim_call_function("bufnr", {})

      if not M.monitored_terminals[buf_nb] then
        M.monitored_terminals[buf_nb] = {}
      end

      M.monitored_terminals[buf_nb].mode = modes.insert

      vim.api.nvim_command("wincmd " .. win_cmd)
    end
  elseif mode == 'n' then
    return function()
      vim.api.nvim_command("wincmd " .. win_cmd)
    end
  end
end

local function warn(msg)
  vim.notify("terminal_insert_switch: " .. msg, vim.log.levels.WARN, { title = 'terminal_insert_switch' })
end

local options = {
  mappings = {},
  add_normal_mode_mappings = false,
}

function M.setup(custom_options)
  local function is_mapping_ok(mapping)
    return #mapping == 2 and type(mapping[1]) == 'string' and type(mapping[2]) == 'string'
  end

  options = vim.tbl_deep_extend("force", options, custom_options or {})

  for _, mapping in pairs(options.mappings) do
    if not is_mapping_ok(mapping) then
      warn("invalid configuration for mapping " .. vim.inspect(mapping) .. ", aborting, see the README")
      return
    end
  end

  local autocmd_group = vim.api.nvim_create_augroup("terminal_switch_autocmds", {})

  -- TODO test with TermEnter
  vim.api.nvim_create_autocmd({"TermOpen"}, {
    group = autocmd_group,

    callback = function()
      -- @Cleanup: call to is_regular_terminal() maybe useless/false
      if not (is_regular_terminal() and not is_cur_window_floating()) then
        return
      end

      for _, mapping in pairs(options.mappings) do
        vim.keymap.set('t', mapping[1], switch_windows_fn(mapping[2], 't'), {buffer = true})
      end

      local buf_nb = vim.api.nvim_call_function("bufnr", {})
      M.monitored_terminals[buf_nb] = { mode = modes.normal }

      vim.api.nvim_create_autocmd({"BufDelete"}, {
        group = autocmd_group,
        buffer = buf_nb,

        callback = function()
          M.monitored_terminals[buf_nb] = nil
        end
      })

      vim.api.nvim_create_autocmd({"BufEnter"}, {
        group = autocmd_group,
        buffer = buf_nb,

        callback = function()
          -- TODO improve doc here
          if M.monitored_terminals[buf_nb].mode == modes.insert then
            vim.api.nvim_command("startinsert")
          else
            -- This is needed as if we are switching from a window in terminal
            -- mode to this terminal window, we end up in terminal mode
            vim.api.nvim_command("stopinsert")
            -- We now have to restore the cursor position. We use vim.schedule
            -- as the command wouldn't work right this moment (as I guess the
            -- buffer isn't fully loaded? Not really sure)
            vim.schedule(
              function()
                vim.api.nvim_win_set_cursor(0, M.monitored_terminals[buf_nb].curs_pos)
              end
            )
          end

          M.monitored_terminals[buf_nb].mode = modes.normal
        end
      })

      vim.api.nvim_create_autocmd({"BufLeave"}, {
        group = autocmd_group,
        buffer = buf_nb,

        callback = function()
          -- leaving a monitored terminal, saving the cursor postion
          M.monitored_terminals[buf_nb].curs_pos = vim.api.nvim_win_get_cursor(0)
        end
      })
    end
  })

  if options.add_normal_mode_mappings then
    for _, mapping in pairs(options.mappings) do
      vim.keymap.set('n', mapping[1], switch_windows_fn(mapping[2], 'n'))
    end
  end
end

return M
