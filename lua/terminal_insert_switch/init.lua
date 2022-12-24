local M = { state = {} }

local modes = { insert = 1, normal = 0 }

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

-- NOTE: this doesn't support doing ':Xwincd win_cmd', with X a number
local function switch_windows_fn(win_cmd, mode)
  if mode == 't' then
    return function()
      local buf_nb = vim.api.nvim_call_function("bufnr", {})

      M.state[buf_nb] = modes.insert

      vim.api.nvim_command("wincmd " .. win_cmd)
    end
  elseif mode == 'n' then
    return function()
      vim.api.nvim_command("wincmd " .. win_cmd)
    end
  end
end

-- TODO is this actually a warning level and not error ?
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
      if is_terminal() and is_regular_terminal() and not is_cur_window_floating() then
        for _, mapping in pairs(options.mappings) do
          vim.keymap.set('t', mapping[1], switch_windows_fn(mapping[2], 't'), {buffer = true})
        end
      end
    end
  })

  vim.api.nvim_create_autocmd({"TermLeave"}, {
    group = autocmd_group,

    callback = function()
      local buf_nb = vim.api.nvim_call_function("bufnr", {})
      M.state[buf_nb] = nil
    end
  })

  vim.api.nvim_create_autocmd({"BufEnter"}, {
    group = autocmd_group,

    callback = function()
      if is_terminal() and is_regular_terminal() then
        local buf_nb = vim.api.nvim_call_function("bufnr", {})

        -- Not previously seen buffer => this is a new buffer, set it to insert mode
        if not M.state[buf_nb] then
          M.state[buf_nb] = modes.normal
        else
          if M.state[buf_nb] == modes.insert then
            vim.api.nvim_command("startinsert")
          end

          M.state[buf_nb] = modes.normal
        end
      end
    end
  })

  if options.add_normal_mode_mappings then
    for _, mapping in pairs(options.mappings) do
      vim.keymap.set('n', mapping[1], switch_windows_fn(mapping[2], 'n'))
    end
  end
end

return M
