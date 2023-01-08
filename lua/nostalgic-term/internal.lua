local internal = {
  modes = { insert = 1, normal = 0 }
}

local modes = internal.modes

local function warn(msg)
  vim.notify("nostalgic-term: " .. msg, vim.log.levels.WARN, { title = 'nostalgic-term' })
end

-- assumes it is running from a terminal buffer
function internal.is_regular_terminal()
  return vim.api.nvim_get_option_value("filetype", {scope = "local"}) == ''
end

function internal.is_cur_window_floating()
  return vim.api.nvim_win_get_config(0).zindex
end

local function get_current_buf_nb()
  return vim.api.nvim_get_current_buf()
end

local function get_current_mode()
  return vim.api.nvim_get_mode().mode
end


function internal.switch_windows_fn(win_cmd)
  return function()
    if vim.v.count ~= 0 then
      vim.api.nvim_command(vim.v.count .. "wincmd " .. win_cmd)
    else
      -- some wincmd commands are unpredictable if given a count of 0
      vim.api.nvim_command("wincmd " .. win_cmd)
    end
  end
end

function internal.vim_terminal_ctrl_w_fn(buf_nb)
  return function()
    vim.api.nvim_command("stopinsert")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<c-w>", true, true, true), 'n', false)

    -- go back to insert mode if we end up in the same terminal
    vim.schedule(function()
      local new_buf_nb = get_current_buf_nb()
      if new_buf_nb == buf_nb then
        vim.api.nvim_command("startinsert")
      end
    end)
  end
end

function internal.are_custom_mappings_valid(options)
  local function is_mapping_ok(mapping)
    return #mapping == 2 and type(mapping[1]) == 'string' and type(mapping[2]) == 'string'
  end

  for _, mapping in pairs(options.mappings) do
    if not is_mapping_ok(mapping) then
      warn("invalid configuration for mapping " .. vim.inspect(mapping) ..
           ", aborting mapping setting, see the README")
      return false
    end
  end

  return true
end

-- from https://github.com/neovim/neovim/issues/18393
local function bufwinid(buf)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(w) == buf then
      return w
    end
  end
  return -1
end

-- TermEnter event for monitored terminals
function internal.set_buf_state_to_insert(monitored_terminals, buf_nb)
  return function()
    monitored_terminals[buf_nb].mode = modes.insert
  end
end

-- TermLeave event for monitored terminals
function internal.set_buf_state_to_normal(monitored_terminals, buf_nb)
  return function()
    -- We don't want to consider switching to another buffer to be a change to
    -- normal mode, so only register a mode change if we stay in the buffer in
    -- normal mode for at least a small amount of time
    vim.defer_fn(function()
      if get_current_buf_nb() == buf_nb and get_current_mode() == 'nt' then
        monitored_terminals[buf_nb].mode = modes.normal
      end
    end, 16)
  end
end

-- BufEnter event for monitored terminals
function internal.switch_to_correct_mode(monitored_terminals, buf_nb)
  return function()
    if monitored_terminals[buf_nb].mode == modes.insert then
      vim.api.nvim_command("startinsert")
    else
      if get_current_mode() == 't' then
        monitored_terminals[buf_nb].curs_pos_valid = false
        -- This is needed as if we are switching from a window in terminal
        -- mode to this terminal window, we will stay in terminal mode
        vim.api.nvim_command("stopinsert")
        -- We now have to restore the cursor position. We use vim.schedule
        -- as the command wouldn't work right this moment (as I guess the
        -- buffer isn't fully loaded? Not really sure)
        vim.schedule(
          function()
            vim.api.nvim_win_set_cursor(bufwinid(buf_nb), monitored_terminals[buf_nb].curs_pos)
            monitored_terminals[buf_nb].curs_pos_valid = true
          end
        )
      end
    end
  end
end

-- BufLeave event for monitored terminals
function internal.save_cursor_position(monitored_terminals, buf_nb)
  return function()
    -- If the user is moving very fast between terminal windows, we may not
    -- have had the time to correctly restore the cursor position in
    -- switch_to_correct_mode, so we skip the saving of the cursor position if
    -- monitored_terminals[buf_nb].curs_pos_valid is false
    if monitored_terminals[buf_nb].mode == modes.normal and monitored_terminals[buf_nb].curs_pos_valid then
      monitored_terminals[buf_nb].curs_pos = vim.api.nvim_win_get_cursor(0)
    end
  end
end

-- BufDelete event for monitored terminals
function internal.remove_from_monitored_terminals(monitored_terminals, buf_nb)
  return function()
    -- Clean up by removing the information we stored for this buffer
    monitored_terminals[buf_nb] = nil
  end
end

return internal
