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
  -- タイポへ飛ぶキー（false にすると割り当てない）
  keys = { next = "]t", prev = "[t" },
  -- 保存後、linter の結果が変わらないときに待つ最大の時間（ミリ秒）
  max_wait = 2000,
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

-- タイポの場所は { lnum = 行(0 始まり), col = 列(0 始まり) } のリストで表す

-- 1. すでに入っている linter が出した diagnostic からタイポを探す
local function find_from_diagnostics(bufnr)
  local found = {}
  local seen = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr)) do
    local source = (d.source or ""):lower()
    for _, name in ipairs(M.config.diagnostic_sources) do
      -- 同じ場所の指摘が重なっていたら 1 つとして数える
      local key = d.lnum .. ":" .. d.col
      if source:find(name, 1, true) and not seen[key] then
        seen[key] = true
        table.insert(found, { lnum = d.lnum, col = d.col })
        break
      end
    end
  end
  return found
end

-- linter の結果が変わったかを比べるための目印（場所と内容をつなげた文字列）
local function diagnostics_signature(bufnr)
  local parts = {}
  for _, d in ipairs(vim.diagnostic.get(bufnr)) do
    local source = (d.source or ""):lower()
    for _, name in ipairs(M.config.diagnostic_sources) do
      if source:find(name, 1, true) then
        table.insert(parts, d.lnum .. ":" .. d.col .. ":" .. (d.message or ""))
        break
      end
    end
  end
  table.sort(parts)
  return table.concat(parts, "\n")
end

-- 2. typos コマンド（typos-cli）が入っていれば、それで探す
local function find_from_typos_cli(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" or vim.fn.executable("typos") == 0 then
    return {}
  end
  local found = {}
  -- 出力は「ファイル名:行:列: ...」の形（行と列は 1 始まり）
  for _, line in ipairs(vim.fn.systemlist({ "typos", "--format", "brief", file })) do
    local lnum, col = line:match(":(%d+):(%d+):")
    if lnum then
      table.insert(found, { lnum = tonumber(lnum) - 1, col = tonumber(col) - 1 })
    end
  end
  return found
end

-- 3. Neovim 標準のスペルチェックでタイポを探す
local function find_from_spell(bufnr)
  if not vim.tbl_contains(M.config.spell_filetypes, vim.bo[bufnr].filetype) then
    return {}
  end
  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return {}
  end
  local found = {}
  vim.api.nvim_win_call(win, function()
    local saved_spell = vim.wo.spell
    local saved_lang = vim.bo.spelllang
    vim.wo.spell = true
    -- cjk を入れて日本語を誤検知しないようにする
    if not saved_lang:find("cjk", 1, true) then
      vim.bo.spelllang = saved_lang .. ",cjk"
    end
    for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      local offset = 0
      local rest = line
      while rest ~= "" do
        local bad = vim.fn.spellbadword(rest)
        local word, kind = bad[1], bad[2]
        if word == "" then
          break
        end
        local s, e = rest:find(word, 1, true)
        if not s then
          break
        end
        if kind == "bad" then
          table.insert(found, { lnum = i - 1, col = offset + s - 1 })
        end
        offset = offset + e
        rest = rest:sub(e + 1)
      end
    end
    vim.wo.spell = saved_spell
    vim.bo.spelllang = saved_lang
  end)
  return found
end

-- 今のバッファにあるタイポの場所を、上から順に並べて返す
function M.find(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.tbl_contains(M.config.exclude_filetypes, vim.bo[bufnr].filetype) then
    return {}
  end
  local found = find_from_diagnostics(bufnr)
  if #found == 0 then
    found = find_from_typos_cli(bufnr)
  end
  if #found == 0 then
    found = find_from_spell(bufnr)
  end
  table.sort(found, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)
  return found
end

function M.check(bufnr)
  local count = #M.find(bufnr)
  if count > 0 then
    notify(count)
  end
  return count
end

-- 次（forward = true）または前のタイポへカーソルを動かす。端まで行ったら反対側に戻る
function M.jump(forward)
  local found = M.find()
  if #found == 0 then
    vim.notify("タイポなし！", vim.log.levels.INFO, { title = "typo-taunt" })
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur = { lnum = cursor[1] - 1, col = cursor[2] }
  local function after(a, b)
    return a.lnum > b.lnum or (a.lnum == b.lnum and a.col > b.col)
  end
  local target
  if forward then
    for _, pos in ipairs(found) do
      if after(pos, cur) then
        target = pos
        break
      end
    end
    target = target or found[1]
  else
    for i = #found, 1, -1 do
      if after(cur, found[i]) then
        target = found[i]
        break
      end
    end
    target = target or found[#found]
  end
  vim.api.nvim_win_set_cursor(0, { target.lnum + 1, target.col })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  local group = vim.api.nvim_create_augroup("TypoTaunt", { clear = true })

  -- 保存したあと、linter の結果がまだ届いていないバッファの情報
  -- { gen = 何回目の待ちか, signature = 保存した時点の linter の結果 }
  local waiting = {}

  local function finish(bufnr, gen)
    local w = waiting[bufnr]
    if not w or w.gen ~= gen then
      return
    end
    waiting[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.check(bufnr)
    end
  end

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      local gen = (waiting[bufnr] and waiting[bufnr].gen or 0) + 1
      waiting[bufnr] = { gen = gen, signature = diagnostics_signature(bufnr) }
      -- linter の結果が変わらないまま時間が過ぎたら、今の結果で数える
      vim.defer_fn(function()
        finish(bufnr, gen)
      end, M.config.max_wait)
    end,
  })

  -- linter が新しい結果を出したら、その結果で数える
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      local w = waiting[bufnr]
      if not w or diagnostics_signature(bufnr) == w.signature then
        return
      end
      w.gen = w.gen + 1
      local gen = w.gen
      -- 結果が続けて届くことがあるので、少し落ち着くのを待つ
      vim.defer_fn(function()
        finish(bufnr, gen)
      end, 300)
    end,
  })

  if M.config.keys then
    if M.config.keys.next then
      vim.keymap.set("n", M.config.keys.next, function()
        M.jump(true)
      end, { desc = "次のタイポへ" })
    end
    if M.config.keys.prev then
      vim.keymap.set("n", M.config.keys.prev, function()
        M.jump(false)
      end, { desc = "前のタイポへ" })
    end
  end
  vim.api.nvim_create_user_command("TypoTaunt", function()
    if M.check() == 0 then
      vim.notify("タイポなし！", vim.log.levels.INFO, { title = "typo-taunt" })
    end
  end, {})
end

return M
