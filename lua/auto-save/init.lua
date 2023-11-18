local M = {}

local autosave_running

vim.api.nvim_create_augroup("AutoSave", {
  clear = true,
})

local global_vars = {}

local function set_buf_var(buf, name, value)
  if buf == nil then
    global_vars[name] = value
  else
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_set_var(buf, "autosave_" .. name, value)
    end
  end
end

local function get_buf_var(buf, name)
  if buf == nil then
    return global_vars[name]
  end
  local success, mod = pcall(vim.api.nvim_buf_get_var, buf, "autosave_" .. name)
  return success and mod or nil
end

local function debounce(lfn, duration)
  local function inner_debounce()
    local buf = vim.api.nvim_get_current_buf()
    if not get_buf_var(buf, "queued") then
      vim.defer_fn(function()
        set_buf_var(buf, "queued", false)
        lfn(buf)
      end, duration)
      set_buf_var(buf, "queued", true)
    end
  end

  return inner_debounce
end

local save_condition = function(buf)
  local disabled_ft = { "oil", "harpoon" }

  return vim.api.nvim_buf_get_option(buf, "modifiable")
      and not vim.tbl_contains(disabled_ft, vim.api.nvim_buf_get_option(buf, "filetype"))
      ---@diagnostic disable-next-line: undefined-field
      and not vim.regex("oil-ssh://"):match_str(vim.api.nvim_buf_get_name(0))
end

function M.save(buf)
  buf = buf or vim.api.nvim_get_current_buf()

  if not save_condition(buf) or not vim.api.nvim_buf_get_option(buf, "modified") or vim.g.auto_save_abort then
    return
  end

  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent! write")
  end)
end

local debounce_delay = 50
local save_func = (debounce_delay > 0 and debounce(M.save, debounce_delay) or M.save)

local function perform_save()
  vim.g.auto_save_abort = false
  save_func()
end

function M.on()
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
    callback = function()
      perform_save()
    end,
    pattern = "*",
    group = "AutoSave",
  })

  autosave_running = true
end

function M.off()
  vim.api.nvim_create_augroup("AutoSave", {
    clear = true,
  })

  autosave_running = false
end

function M.toggle()
  if autosave_running then
    M.off()
  else
    M.on()
  end
end

return M
