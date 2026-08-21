local M = {}

-- Default configuration. Override any field through `setup(opts)`
-- (or, with lazy.nvim, the `opts` table of the plugin spec).
M.config = {
  -- Directory that holds `<name>.txt` template files, one participant per line.
  templates_dir = vim.fn.expand("~/.config/standup"),

  -- Inline templates: name -> list of participants.
  -- These merge with the templates loaded from `templates_dir`.
  -- Example: templates = { team = { "Ada", "Grace", "Alan" } }
  templates = {},

  -- Per-buffer normal-mode keymaps.
  keymaps = {
    toggle = "t", -- tick / untick the current line
    random = "r", -- jump to a random unticked participant
    close = "q", -- close the standup buffer
  },
}

local ns = vim.api.nvim_create_namespace("standup")

-- Read every `<name>.txt` file in `dir`. Each non-empty line is one participant.
local function load_templates(dir)
  local templates = {}
  local files = vim.fn.glob(dir .. "/*.txt", false, true)
  for _, path in ipairs(files) do
    local name = vim.fn.fnamemodify(path, ":t:r")
    local names = {}
    for line in io.lines(path) do
      local trimmed = line:match("^%s*(.-)%s*$")
      if trimmed ~= "" then
        table.insert(names, trimmed)
      end
    end
    if #names > 0 then
      templates[name] = names
    end
  end
  return templates
end

-- Merge inline templates with the ones found on disk. Disk wins on name clash.
local function all_templates()
  local templates = vim.deepcopy(M.config.templates or {})
  for name, names in pairs(load_templates(M.config.templates_dir)) do
    templates[name] = names
  end
  return templates
end

local function refresh_highlights(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if line:match("^%[x%]") then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_row = i - 1,
        end_col = #line,
        hl_group = "StandupDone",
      })
    end
  end
end

-- Move unticked names to the top, ticked names to the bottom.
-- Keep the relative order within each group stable.
local function sort_lines(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local unticked, ticked = {}, {}
  for _, line in ipairs(lines) do
    if line:match("^%[x%]") then
      table.insert(ticked, line)
    else
      table.insert(unticked, line)
    end
  end
  local sorted = {}
  for _, line in ipairs(unticked) do
    table.insert(sorted, line)
  end
  for _, line in ipairs(ticked) do
    table.insert(sorted, line)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, sorted)
end

local function setup_buf_keymaps(buf)
  local keys = M.config.keymaps
  local opts = { buffer = buf, noremap = true, silent = true }

  -- toggle tick on the current line
  vim.keymap.set("n", keys.toggle, function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local new_line
    if line:match("^%[ %]") then
      new_line = line:gsub("^%[ %]", "[x]", 1)
    elseif line:match("^%[x%]") then
      new_line = line:gsub("^%[x%]", "[ ]", 1)
    else
      return
    end
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
    sort_lines(buf)
    refresh_highlights(buf)
  end, vim.tbl_extend("force", opts, { desc = "Standup: toggle tick" }))

  -- jump to a random unticked name
  vim.keymap.set("n", keys.random, function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local unticked = {}
    for i, line in ipairs(lines) do
      if line:match("^%[ %]") then
        table.insert(unticked, i)
      end
    end
    if #unticked == 0 then
      vim.notify("Standup complete — everyone has talked!", vim.log.levels.INFO)
      return
    end
    local idx = unticked[math.random(#unticked)]
    vim.api.nvim_win_set_cursor(0, { idx, 4 })
  end, vim.tbl_extend("force", opts, { desc = "Standup: random unticked" }))

  -- close the buffer
  vim.keymap.set("n", keys.close, "<cmd>bdelete<cr>", vim.tbl_extend("force", opts, { desc = "Standup: close" }))
end

function M.open(template_name)
  local names = all_templates()[template_name]
  if not names then
    vim.notify("Standup: template not found: " .. template_name, vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "Standup: " .. template_name)
  vim.bo[buf].filetype = "standup"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  local lines = vim.tbl_map(function(name)
    return "[ ] " .. name
  end, names)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.api.nvim_set_current_buf(buf)
  setup_buf_keymaps(buf)
  refresh_highlights(buf)
end

function M.pick_template()
  local templates = vim.tbl_keys(all_templates())
  if #templates == 0 then
    vim.notify("Standup: no templates configured", vim.log.levels.WARN)
    return
  end
  table.sort(templates)
  if #templates == 1 then
    M.open(templates[1])
    return
  end
  vim.ui.select(templates, { prompt = "Standup template:" }, function(choice)
    if choice then
      M.open(choice)
    end
  end)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Seed the RNG so `random` is not deterministic across sessions.
  math.randomseed(os.time())

  vim.api.nvim_set_hl(0, "StandupDone", { link = "Comment", strikethrough = true })

  vim.api.nvim_create_user_command("Standup", function(args)
    if args.args ~= "" then
      M.open(args.args)
    else
      M.pick_template()
    end
  end, {
    nargs = "?",
    complete = function()
      return vim.tbl_keys(all_templates())
    end,
  })
end

return M
