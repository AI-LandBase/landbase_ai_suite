---
name: contribution-meter
description: "Use when the user asks to measure contributor contributions, calculate contribution percentages, analyze team member activity, or mentions '貢献度', 'コントリビューション', '貢献割合', '貢献度測定'. Interactively collects GitHub data (issue estimates, PR reviews, comments) and calculates weighted contribution scores."
---

# Contribution Meter

GitHub リポジトリの貢献度を対話的に測定する。Issue見積もり工数・レビュー/マージ数・コメント数を重み付けして総合貢献度（%）を算出する。

## 前提条件

- `gh` CLI が認証済みであること
- Issue本文に見積もり工数が記載されていること
- PRタイトルに `(issue#XXX)` 形式でIssue番号が含まれること

## 設定

以下の値はプロジェクトに合わせて変更可能。Python スクリプト内の該当箇所を編集する。

### 見積もり工数の正規表現パターン
```python
ESTIMATE_PATTERNS = [
    r'\*{0,2}合計見積\*{0,2}[:\s]*([0-9.]+)\s*(?:時間|h)',
    r'\*{0,2}工数見積\*{0,2}[:\s]*([0-9.]+)\s*(?:時間|h)',
]
```

### PRタイトルからIssue番号を抽出するパターン
```python
ISSUE_REF_PATTERN = r'issue#(\d+)'
```

### 重みの配分
```python
W_DEV = 0.7       # 開発工数の重み（70%）
W_REVIEW = 0.2    # レビュー/マージの重み（20%）
W_COMMENT = 0.1   # コメントの重み（10%）
```

### 見積もりなしIssueへの追記フォーマット
Issue本文の末尾に以下を追加する:
```markdown
---

## ⏱️ 工数見積

合計見積: X時間

工数見積: X時間
優先度: Medium
難易度: Low
```

## 対話フロー

以下のステップを順番に実行する。エラーが発生したら停止してユーザーに報告する。

### Step 1: 期間の選択

ユーザーに分析対象の期間を確認する:

> 貢献度を測定します。分析対象の期間を選んでください:
>
> - **A) 全期間**（デフォルト）
> - **B) カスタム** — 開始日と終了日を YYYY-MM-DD で指定

ユーザーの回答に応じて `START_DATE` と `END_DATE` を設定する。全期間の場合は空文字列とする。

### Step 2: データ収集

以下の Python スクリプトを Bash で実行し、3つの指標を一括収集する。
`START_DATE` と `END_DATE` はStep 1で決定した値に置き換える。

```bash
python3 << 'PYEOF'
import json, re, subprocess, sys
from datetime import datetime

# --- 設定（変更可） ---
ESTIMATE_PATTERNS = [
    r'\*{0,2}合計見積\*{0,2}[:\s]*([0-9.]+)\s*(?:時間|h)',
    r'\*{0,2}工数見積\*{0,2}[:\s]*([0-9.]+)\s*(?:時間|h)',
]
ISSUE_REF_PATTERN = r'issue#(\d+)'
START_DATE = ""  # 空 = 全期間、または "YYYY-MM-DD"
END_DATE = ""    # 空 = 全期間、または "YYYY-MM-DD"
# --- 設定ここまで ---

def in_range(date_str):
    if not date_str or (not START_DATE and not END_DATE):
        return True
    dt = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
    if START_DATE and dt < datetime.fromisoformat(START_DATE + "T00:00:00+00:00"):
        return False
    if END_DATE and dt > datetime.fromisoformat(END_DATE + "T23:59:59+00:00"):
        return False
    return True

def gh_json(args):
    result = subprocess.run(["gh"] + args, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR: gh {' '.join(args)} failed: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return json.loads(result.stdout) if result.stdout.strip() else []

# --- 1. マージ済みPR取得 ---
prs = gh_json(["pr", "list", "--state", "merged", "--limit", "500",
               "--json", "number,title,author,mergedBy,mergedAt"])

issue_to_author = {}
pr_issue_merger = {}  # {issue_num: (merger, mergedAt)}
for pr in prs:
    if not in_range(pr.get("mergedAt")):
        continue
    author = pr["author"]["login"]
    match = re.search(ISSUE_REF_PATTERN, pr["title"])
    if match:
        issue_num = int(match.group(1))
        issue_to_author[issue_num] = author
        pr_issue_merger[issue_num] = pr["mergedBy"]["login"]

# --- 2. Issue見積もり工数 ---
issues = gh_json(["issue", "list", "--state", "all", "--limit", "500",
                  "--json", "number,title,body"])
issue_hours = {}  # {issue_num: hours}
dev_totals = {}
no_estimate = []
for issue in issues:
    num = issue["number"]
    body = issue.get("body", "") or ""
    hours = None
    for pat in ESTIMATE_PATTERNS:
        m = re.search(pat, body)
        if m:
            hours = float(m.group(1))
            break
    if hours is not None:
        issue_hours[num] = hours
        assignee = issue_to_author.get(num)
        if assignee:
            dev_totals[assignee] = dev_totals.get(assignee, 0) + hours
    else:
        if num in issue_to_author:
            no_estimate.append({"number": num, "title": issue["title"]})

# --- 2b. レビュー工数（見積もり時間ベース） ---
review_totals = {}
for issue_num, merger in pr_issue_merger.items():
    hours = issue_hours.get(issue_num, 0)
    if hours > 0:
        review_totals[merger] = review_totals.get(merger, 0) + hours

# --- 3. コメント工数（見積もり時間ベース） ---
comment_result = subprocess.run(
    ["gh", "api", "repos/{owner}/{repo}/issues/comments", "--paginate",
     "--jq", "[.[] | {login: .user.login, created_at: .created_at, issue_url: .issue_url}]"],
    capture_output=True, text=True
)
# --paginate + --jq で各ページが独立JSON配列になるため結合する
raw = comment_result.stdout.strip()
comments = []
if raw:
    for chunk in raw.split("\n"):
        chunk = chunk.strip()
        if chunk:
            comments.extend(json.loads(chunk))
comment_totals = {}
comment_seen = set()  # (login, issue_num) の重複排除
for c in comments:
    if not in_range(c.get("created_at")):
        continue
    login = c["login"]
    if login.endswith("[bot]"):
        continue
    # issue_url からIssue番号を抽出し、見積もり時間で重み付け
    issue_num_match = re.search(r'/issues/(\d+)$', c.get("issue_url", ""))
    if issue_num_match:
        inum = int(issue_num_match.group(1))
        key = (login, inum)
        if key in comment_seen:
            continue
        comment_seen.add(key)
        hours = issue_hours.get(inum, 0)
        if hours > 0:
            comment_totals[login] = comment_totals.get(login, 0) + hours

# --- 出力 ---
output = {
    "dev_totals": dev_totals,
    "review_totals": review_totals,
    "comment_totals": comment_totals,
    "no_estimate": no_estimate,
    "period": {"start": START_DATE or "全期間", "end": END_DATE or "全期間"},
}
print(json.dumps(output, ensure_ascii=False, indent=2))
PYEOF
```

スクリプトの出力 JSON を読み取り、次のステップで中間結果を表示する。

### Step 3: 中間結果を表示

Step 2 の出力 JSON から、以下のフォーマットでユーザーに表示する:

```
=== 担当者別 開発工数（期間: {start} 〜 {end}） ===
  {user}: {hours}h ({pct}%)
  ...
  合計: {total}h

=== レビュー/マージ工数 ===
  {user}: {hours}h ({pct}%)
  ...

=== コメント工数 ===
  {user}: {hours}h ({pct}%)
  ...
```

`no_estimate` が空でない場合、追加で警告を表示:

```
⚠️ 見積もりなしIssue（PRに紐づくもの）: {count}件
```

### Step 4: 見積もりなしIssueの処理

`no_estimate` が空でない場合のみ実行する。空なら Step 5 へスキップ。

ユーザーに確認:

> 見積もりなしのIssueが {count}件 あります。見積もりを追記しますか？
>
> - **A) 追記する** — 各Issueの内容を確認して見積もりを提案
> - **B) スキップ** — 現在のデータのまま進める

**A を選択した場合:**

1. 見積もりなしIssueの一覧を表示:
   ```
   | # | タイトル |
   |---|---------|
   | #XXX | タイトル |
   ```

2. 各Issueについて `gh issue view {number} --json body` で本文を取得し、内容から見積もり時間を提案する。

3. ユーザー確認後、以下の手順でIssue本文を更新:
   - `gh issue view {number} --json body --jq '.body'` で既存本文を取得
   - 見積もりセクションを末尾に追記した全文を作成
   - `gh issue edit {number} --body-file` で更新

   追記する見積もりセクションのフォーマット:
   ```markdown
   ---

   ## ⏱️ 工数見積

   合計見積: {X}時間

   工数見積: {X}時間
   優先度: Medium
   難易度: Low
   ```

4. 全件追記後、Step 2 のデータ収集スクリプトを再実行して `dev_totals` を更新する。

5. 更新された中間結果を Step 3 のフォーマットで再表示する。

### Step 5: 最終結果を表示

Step 2（または Step 4 で再集計した結果）の JSON と、設定セクションの重み（`W_DEV`, `W_REVIEW`, `W_COMMENT`）を使い、以下の Python スクリプトで算出する:

```bash
python3 << 'PYEOF'
import json

# --- Step 2/4 の出力から取得した値を埋める ---
dev_totals = {}     # {"user": hours, ...}
review_totals = {}  # {"user": hours, ...}
comment_totals = {} # {"user": hours, ...}
W_DEV = 0.7
W_REVIEW = 0.2
W_COMMENT = 0.1
# --- ここまで ---

all_users = sorted(set(list(dev_totals.keys()) + list(review_totals.keys()) + list(comment_totals.keys())))

dev_grand = sum(dev_totals.values()) or 1
review_grand = sum(review_totals.values()) or 1
comment_grand = sum(comment_totals.values()) or 1

scores = {}
for u in all_users:
    d = (dev_totals.get(u, 0) / dev_grand) * 100
    r = (review_totals.get(u, 0) / review_grand) * 100
    c = (comment_totals.get(u, 0) / comment_grand) * 100
    scores[u] = d * W_DEV + r * W_REVIEW + c * W_COMMENT

total_score = sum(scores.values()) or 1

print("=== 最終結果 ===")
print(f"重み: 開発 {W_DEV*100:.0f}% / レビュー {W_REVIEW*100:.0f}% / コメント {W_COMMENT*100:.0f}%\n")

print("| 担当者 | 開発 | レビュー | コメント | 総合貢献度 |")
print("|--------|-----:|--------:|--------:|---------:|")
for u in sorted(scores, key=lambda x: -scores[x]):
    d = (dev_totals.get(u, 0) / dev_grand) * 100
    r = (review_totals.get(u, 0) / review_grand) * 100
    c = (comment_totals.get(u, 0) / comment_grand) * 100
    final = scores[u] / total_score * 100
    print(f"| {u} | {d:.1f}% | {r:.1f}% | {c:.1f}% | **{final:.1f}%** |")
PYEOF
```

上記スクリプトの変数 `dev_totals`, `review_totals`, `comment_totals` には、これまでのステップで収集した実際の値を埋めて実行する。`W_DEV`, `W_REVIEW`, `W_COMMENT` は設定セクションの値を使用する。全指標が見積もり時間（h）ベースのため、大きなIssueのレビュー・コメントほど高く評価される。

結果をユーザーに Markdown テーブルとして表示する。
