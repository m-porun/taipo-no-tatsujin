# typo-taunt

Neovim で `:w` 保存したときにタイポを見つけると、「タイポの達人♪」と煽ってくれるプラグインです。

## しくみ

保存すると、次の順番でタイポを数えます。最初に見つかった方法の結果を使います。

1. すでに入っている linter の結果（diagnostic）のうち、`cspell`・`typos`・`codespell`・`misspell` が出したもの
2. `typos` コマンド（typos-cli）が入っていれば、その結果
3. Markdown・テキスト・コミットメッセージなら、Neovim 標準のスペルチェック

タイポがあれば、次の 2 つで知らせます。

- 通知バーに「タイポの達人♪（N 個）」と表示
- macOS なら `say` コマンドで「タイポの達人♪」と読み上げ

## LazyVim で読み込む

まず、`~/.config/nvim/lua/plugins/typo-taunt.lua` を作り、次の内容を書きます。
`dir` は、このリポジトリを置いた場所に合わせて直してください。

```lua
return {
  {
    dir = "~/path/to/webapp_workshop_20261004/typo-taunt",
    name = "typo-taunt",
    event = "VeryLazy",
    opts = {},
  },
}
```

終わったら Neovim を開き直して、`:w` で保存してみてください。

## 試し方

- 英語でわざと `speling` と書いた Markdown を保存する
- `:TypoTaunt` で、保存しなくても今のファイルを調べられる

## 設定

`opts` で変えられます。

```lua
opts = {
  message = "タイポの達人♪",   -- セリフ
  voice = true,                 -- 読み上げるかどうか
  say_voice = "Kyoko",          -- macOS の声
}
```
