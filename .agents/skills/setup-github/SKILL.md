---
name: setup-github
description: Use when a beginner has already cloned a starter repository and needs to create their own GitHub repository, point origin to it, and push their current branch during a workshop
---

# Set Up GitHub

この skill は、初学者が公開 repository を clone 済みの状態から、自分の GitHub repository を用意して push できる形にするときに使います。

ゴールは次の2つです。

- `origin` が参加者自身の GitHub repository を向いている
- 現在の branch を自分の GitHub repository に push できている

## 使う場面

次の条件がそろったら使います。

- 参加者は PC 操作はできるが、Git 操作に慣れていない
- 公開 repository はすでに clone 済み
- push 先は参加者自身の GitHub repository にしたい
- 参加者はまだ自分の GitHub repository を用意していないか、remote 設定ができていない

次の場面では使いません。

- すでに `origin` が自分の GitHub repository になっていて push も済んでいる
- fork を前提にした運用にしたい
- 複数人で同じ repository に共同 push する運用を組みたい

## 基本方針

- 参加者に、今やることをその都度はっきり伝える
- 1ステップずつ進め、各ステップが終わってから次へ進む
- 参加者に長い Git 理論は説明しない
- GitHub 側で空 repository を作る案内を先に入れる
- `origin` は参加者の repository、`upstream` は元の公開 repository にする
- 最後は `git remote -v` と push 成功を必ず確認する
- branch 名は固定で決めつけず、必要なら現在の branch を確認してから push する

## 進め方

### 1. 作業場所を確認する

参加者が、clone 済みの repository フォルダを開いている前提で進めます。
親フォルダを開いているだけのことがあるので、必要なら「clone してできた repository フォルダを開いてください」と伝えます。

例:

```text
~/project/my-webapp
  └─ webapp_workshop
```

この場合、実際の作業場所は `webapp_workshop` です。

### 2. GitHub アカウント名を聞く

最初に、参加者の GitHub アカウント名を聞きます。
まだ repository URL は聞かなくて構いません。

このワークショップで使う公開 repository は次です。

```text
https://github.com/RilaKorila/webapp_workshop
```

### 3. その場で空 repository を作る案内をする

GitHub アカウント名がわかったら、参加者に空 repository を作る案内をします。

案内の要点:

- GitHub で新しい repository を作る
- owner は参加者のアカウントにする
- repository 名は現在の作業フォルダ名か、講師が指定した名前にする
- `README` は追加しない
- `.gitignore` は追加しない
- license も追加しない

repository が作れたら、その URL を確認します。

### 4. remote 切り替えを進める

repository URL がわかったら、参加者に今やることを小さく区切って案内します。
このステップでは、次を順番に進めます。

- 今ある clone の push 先を自分の repository に変える
- 元の公開 repository は `upstream` として残す

説明は短くしてよいですが、参加者が次に押すもの、入力するもの、実行するものがわかる形で伝えます。

### 5. 最初の push を進める

remote の確認後、次の順番で案内します。

1. 必要なら現在の branch 名を確認する
2. その branch を origin に push する
3. `git remote -v` を実行して、向き先を確認する

1回の返答で全部を詰め込みすぎず、今やる操作をはっきり示します。

## 完了条件

次の条件がそろったら完了です。

1. `git remote -v` で、`origin` が参加者の GitHub repository になっている
2. `git remote -v` で、`upstream` が元の公開 repository になっている
3. 現在の branch の最初の push が成功している

## 最終確認

最後に次を確認します。

- `git remote -v`
- `git status`
- 必要なら `git branch --show-current`

push 後は、結果を短く言い換えます。

- `origin` は自分の repository
- `upstream` は元の公開 repository
- ここからの変更は自分の GitHub に push できる

## よくある失敗

- 親フォルダを開いたままで、clone された repository フォルダに入っていない
- `origin` がまだ公開 repository のまま
- `origin` を消したあと、新しい `origin` を追加していない
- 自分の GitHub repository が空 repository ではなく、初期ファイル付きで競合する
- branch 名を確認せずに `main` だと思い込んで push しようとする

## 応答のしかた

- 日本語で短く案内する
- 1回にやることを絞る
- 「まずこれをする」「終わったら次にこれをする」という順番を明記する
- 参加者が今どこで止まっているかを確認しながら進める
- Git 用語を使ったらすぐに言い換える
- 失敗時は、足りないものを先に伝えてから次の操作に進まない
- 長い講義調の説明はしない
