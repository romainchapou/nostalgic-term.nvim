local internal = {
  modes = { insert = 1, normal = 0 }
}

local modes = internal.modes

local function warn(msg)
  vim.notify("vim-term-mimic: " .. msg, vim.log.levels.WARN, { title = 'vim-term-mimic' })
end

-- assumes it is running from a terminal buffer
function internal.is_regular_terminal()
  return vim.api.nvim_get_option_value("filetype", {scope = "local"}) == ''
end

function internal.is_cur_window_floating()
  return vim.api.nvim_win_get_config(0).zindex
end

function internal.get_cur_buf_nb()
  return vim.api.nvim_call_function("bufnr", {})
end


-- NOTE: this doesn't support doing ':Xwincd win_cmd', with X a number
function internal.switch_windows_fn(win_cmd, mode, monitored_terminals, buf_nb)
  if mode == 't' then
    return function()
      monitored_terminals[buf_nb].mode = modes.insert

      vim.api.nvim_command("wincmd " .. win_cmd)
    end
  elseif mode == 'n' then
    return function()
      if vim.v.count ~= 0 then
        vim.api.nvim_command(vim.v.count .. "wincmd " .. win_cmd)
      else
        -- some wincmd commands are unpredictable if given a count of 0
        vim.api.nvim_command("wincmd " .. win_cmd)
      end
    end
  end
end

function internal.vim_terminal_ctrl_w_fn(monitored_terminals, buf_nb)
  return function()
    monitored_terminals[buf_nb].mode = modes.insert

    vim.api.nvim_command("stopinsert")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-w>", true, true, true), 'n', false)

    -- go back to insert mode if we end up in the same terminal
    vim.schedule(function()
      local new_buf_nb = internal.get_cur_buf_nb()
      if new_buf_nb == buf_nb then
        vim.api.nvim_command("startinsert")
      end
    end)
  end
end

function internal.are_custom_options_valid(options)
  local function is_mapping_ok(mapping)
    return #mapping == 2 and type(mapping[1]) == 'string' and type(mapping[2]) == 'string'
  end

  for _, mapping in pairs(options.mappings) do
    if not is_mapping_ok(mapping) then
      warn("invalid configuration for mapping " .. vim.inspect(mapping) .. ", aborting, see the README")
      return false
    end
  end

  return true
end

function internal.switch_to_correct_mode_and_update(monitored_terminals, buf_nb)
  return function()
    -- TODO improve the doc here
    if monitored_terminals[buf_nb].mode == modes.insert then
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
          vim.api.nvim_win_set_cursor(0, monitored_terminals[buf_nb].curs_pos)
        end
      )
    end

    monitored_terminals[buf_nb].mode = modes.normal
  end
end

function internal.save_cursor_position(monitored_terminals, buf_nb)
  return function()
    monitored_terminals[buf_nb].curs_pos = vim.api.nvim_win_get_cursor(0)
  end
end

function internal.remove_from_monitored_terminals(monitored_terminals, buf_nb)
  return function()
    monitored_terminals[buf_nb] = nil
  end
end

return internal
