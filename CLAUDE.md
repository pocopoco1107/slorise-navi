# スロリセnavi - プロジェクトガイド

## プロジェクト概要
パチスロの設定・リセット情報を匿名ワンタップ投票で集め、集合知として蓄積するCGMサイト。

## 技術スタック
- **Ruby 4.0.0** / **Rails 8.0.4** / **PostgreSQL 17**
- Hotwire (Turbo + Stimulus) / Tailwind CSS v4
- Devise (管理者認証のみ) / ActiveAdmin
- pg_search / kaminari / rack-attack / meta-tags / sitemap_generator
- RSpec + FactoryBot + Faker
- デプロイ先: Render.com（未デプロイ）

## 環境セットアップ
```bash
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
brew services start postgresql@17
bundle install
bin/rails db:create db:migrate db:seed
bin/dev  # サーバー起動 (Tailwind watch + Rails)
```

## 重要な設計判断
- **ログイン不要**: 公開機能は全て匿名。Cookie (`voter_token`) で重複投票防止
- **管理者のみDevise**: `/admin` へのアクセスのみログイン必須
- **コンテナ不要**: Docker/Kamal削除済み。Render.comにGit直接デプロイ
- **1人1日1店舗1機種1票**: `voter_token + shop_id + machine_model_id + voted_on` でユニーク制約

## 主要モデル
| モデル | 概要 |
|--------|------|
| Prefecture | 47都道府県 (seed) |
| Shop | 店舗 (5,761件。レート・換金率・台数・駐車場・電話・朝入場・アクセス・特徴・喫煙詳細等) |
| MachineModel | パチスロ機種 (active: ~1,300 / inactive: ~3,500。trophy_rules, display_typeあり) |
| ShopMachineModel | 店舗×機種の設置紐づけ (N:N中間テーブル) |
| Vote | 投票 (voter_tokenで匿名識別。confirmed_setting配列あり) |
| VoteSummary | 投票集計キャッシュ (Vote保存時に自動更新) |
| SnsReport | SNS/RSS自動収集データ (トロフィー・確定演出情報) |
| Feedback | ユーザー要望・不具合報告 |
| Comment | コメント (匿名、commenter_name任意) |
| Report | 通報 |

## 重要ファイル
- `app/views/shops/show.html.erb` — 最重要ページ（投票UI）
- `app/views/shops/_machine_vote_row.html.erb` — Turbo Frame投票行
- `app/views/home/index.html.erb` — ホームページ（ヒーロー+統計+ランキング）
- `app/controllers/votes_controller.rb` — 投票ロジック（リセット/設定を個別マージ）
- `app/models/vote_summary.rb` — `refresh_for` で集計更新
- `config/initializers/rack_attack.rb` — レート制限

## Seed管理者
- email: admin@example.com / password: password

## Git
- リポジトリ: https://github.com/pocopoco1107/slorise-navi (Private)
- ローカルgit user: pocopoco1107 (--local設定)
- グローバルgit (shota-kaseda) はこのプロジェクトでは使わない

## Stimulusコントローラ
| コントローラ | 機能 |
|-------------|------|
| vote | 投票ボタンの無効化+pulseアニメーション |
| accordion | 都道府県地域の開閉 |
| favorite | 店舗お気に入りトグル (localStorage) |
| favorites-list | ホームでお気に入り店舗一覧表示 |
| machine-filter | 店舗ページの機種名絞り込み + 県ページの店舗名絞り込み（市区町村グループ対応） |
| machine-search | 店舗ページで機種検索→投票行追加 |
| dismissable | アラート等の非表示 |

## テスト
```bash
bundle exec rspec  # 117 examples, 0 failures
```

## Rakeタスク（pworld:）
| タスク | 説明 |
|--------|------|
| `scrape_shops[slug]` | 都道府県の店舗をP-WORLDからインポート |
| `scrape_shop_details` | 全店舗の詳細情報を取得（営業時間/駐車場/電話等、約4時間） |
| `scrape_shop_details_by_pref[slug]` | 県単位で詳細取得 |
| `refresh_shop_machines` | 全店舗の設置機種リスト更新 |
| `refresh_by_pref[slug]` | 県単位で設置機種更新 |
| `import_machines` | 機種マスタ更新（新台含む） |
| `cleanup_orphan_machines` | 設置0の機種を非アクティブ化 |
| `update_unit_counts` | 全店舗の機種別設置台数を更新（数字画像デコード方式） |
| `update_unit_counts_by_pref[slug]` | 県単位で設置台数更新 |
| `weekly_refresh` | 週次バッチ（新台+設置機種+クリーンアップ） |
| `monthly_refresh` | 月次バッチ（店舗詳細の全項目再取得） |

## ユーザーの方針
- ログイン式にしない
- コンテナ管理不要
- 最新・トレンド技術を好む
- 破壊的操作は事前確認必須
- 会社アカウント (shota-kaseda / spice-factory) をこのプロジェクトで使わない

---

## データ品質ルール（毎回チェック必須）

### スクレイピング後の必須チェック
1. **パチンコ混入チェック**: 以下パターンに該当する機種がないか確認
   - 全角: `Ｐ`, `ＣＲ`, `ｅ` で始まる
   - 半角: `PA`, `P `, `P+日本語`, `PF`, `CR` で始まる
   - キーワード: `ぱちんこ`, `デジハネ`, `甘デジ`, `羽根モノ`
2. **重複チェック**: Unicode NFKC正規化で全角/半角の重複がないか
3. **件数の妥当性チェック**: 変更前後の件数を表示し、大幅な増減がないか確認
4. **レート・設備情報の取得率を報告** (目標: レート75%+, 設備88%+)

### P-WORLDスクレイピング規約
- エンコーディング: EUC-JP (`Encoding::EUC_JP`)
- レート制限: `sleep 2.5` (1リクエストあたり)
- User-Agent: 標準ブラウザUA使用
- Net::HTTP直接使用 (WebFetchは404になる)

## UI/フロントエンド規約

### Tailwind CSS v4
- `@import "tailwindcss"` + `@theme` ブロック (v4形式)
- カスタムカラーは `app/assets/tailwind/application.css` の `@theme` で定義
- 設定ヒートマップ: 1=blue→2=cyan→3=emerald→4=amber→5=orange→6=red

### Hotwire パターン
- 投票UI: Turbo Frame (`<turbo-frame id="vote_...">`) で部分更新
- 開閉UI: Stimulus `accordion` コントローラ
- お気に入り: localStorage + Stimulus `favorite` / `favorites-list`
- フィルタ: Stimulus `machine-filter` コントローラ

### モバイルファースト
- `sm:` ブレークポイントでデスクトップ対応
- タップ領域: 最小44x44px
- 機種投票行: コンパクトさ重視（縦幅を抑える）

## Rakeタスク命名規約
- namespace: `pworld:`
- 都道府県指定: `rake pworld:task_name[prefecture_slug]`
- 全国一括: `rake pworld:task_name` (引数なし)
- 進捗表示: `puts "#{index}/#{total} ..."` 形式
