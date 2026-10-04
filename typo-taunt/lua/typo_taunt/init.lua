-- typo-taunt: :w で保存したときにタイポを見つけたら「タイポの達人♪」と煽るプラグイン
local M = {}

M.config = {
  -- 通知に出す煽りのセリフ
  message = "タイポの達人♪",
  -- 音声で読み上げるセリフ（♪ は読まない）
  speech = "タイポの達人",
  -- 音声で話すかどうか
  voice = true,
  -- macOS の say で使う声（日本語の声）
  say_voice = "Kyoko",
  -- タイポを数えるのに使う linter の名前（diagnostic の source）
  diagnostic_sources = { "typos", "cspell", "codespell", "misspell", "typos_lsp" },
  -- 煽る対象から外すファイルタイプ
  exclude_filetypes = { "help", "lazy", "mason" },
  -- Neovim 標準のスペルチェックを使うファイルタイプ（コードだと変数名まで拾うため文章系だけ）
  spell_filetypes = { "markdown", "text", "gitcommit" },
}

local function notify(count)
  local text = string.format("%s（%d 個）", M.config.message, count)
  vim.notify(text, vim.log.levels.WARN, { title = "typo-taunt" })

  if not M.config.voice then
    return
  end
  if vim.fn.executable("say") == 1 then
    -- macOS の音声合成
    vim.fn.jobstart({ "say", "-v", M.config.say_voice, M.config.speech })
  elseif vim.fn.executable("spd-say") == 1 then
    vim.fn.jobstart({ "spd-say", "-l", "ja", M.config.speech })
  elseif vim.fn.executable("espeak") == 1 then
    vim.fn.jobstart({ "espeak", "-v", "ja", M.config.speech })
  end
end

-- 1. すでに入っている linter が出した diagnostic からタイポを数える
local function count_from_diagnostics(bufnr)
  local count = 0
  for _, d in ipairs(vim.diagnostic.get(bufnr)) do
    local source = (d.source or ""):lower()
    for _, name in ipairs(M.config.diagnostic_sources) do
      if source:find(name, 1, true) then
        count = count + 1
        break
      end
    end
  end
  return count
end

-- 2. typos コマンド（typos-cli）が入っていれば、それで数える
local function count_from_typos_cli(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" or vim.fn.executable("typos") == 0 then
    return 0
  end
  local out = vim.fn.systemlist({ "typos", "--format", "brief", file })
  local count = 0
  for _, line in ipairs(out) do
    if line ~= "" then
      count = count + 1
    end
  end
  return count
end

-- 3. Neovim 標準のスペルチェックでタイポを数える
local function count_from_spell(bufnr)
  if not vim.tbl_contains(M.config.spell_filetypes, vim.bo[bufnr].filetype) then
    return 0
  end
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return 0
  end
  local count = 0
  vim.api.nvim_win_call(win, function()
    local saved_spell = vim.wo.spell
    local saved_lang = vim.bo.spelllang
    vim.wo.spell = true
    -- cjk を入れて日本語を誤検知しないようにする
    if not saved_lang:find("cjk", 1, true) then
      vim.bo.spelllang = saved_lang .. ",cjk"
    end
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      local rest = line
      while rest ~= "" do
        local bad = vim.fn.spellbadword(rest)
        local word, kind = bad[1], bad[2]
        if word == "" then
          break
        end
        if kind == "bad" then
          count = count + 1
        end
        local s, e = rest:find(word, 1, true)
        if not s then
          break
        end
        rest = rest:sub(e + 1)
      end
    end
    vim.wo.spell = saved_spell
    vim.bo.spelllang = saved_lang
  end)
  return count
end

function M.check(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.tbl_contains(M.config.exclude_filetypes, vim.bo[bufnr].filetype) then
    return 0
  end
  local count = count_from_diagnostics(bufnr)
  if count == 0 then
    count = count_from_typos_cli(bufnr)
  end
  if count == 0 then
    count = count_from_spell(bufnr)
  end
  if count > 0 then
    notify(count)
  end
  return count
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  local group = vim.api.nvim_create_augroup("TypoTaunt", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      -- linter が保存直後に diagnostic を更新するのを少し待ってから調べる
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          M.check(args.buf)
        end
      end, 500)
    end,
  })
  vim.api.nvim_create_user_command("TypoTaunt", function()
    if M.check() == 0 then
      vim.notify("タイポなし！", vim.log.levels.INFO, { title = "typo-taunt" })
    end
  end, {})
end

return M
