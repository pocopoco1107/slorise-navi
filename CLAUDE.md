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
| Shop | 店舗 (15件seed。レート・換金率・台数・旧イベント日等) |
| MachineModel | パチスロ機種 (30件seed) |
| Vote | 投票 (voter_tokenで匿名識別) |
| VoteSummary | 投票集計キャッシュ (Vote保存時に自動更新) |
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

## テスト
```bash
bundle exec rspec  # 19 examples, 0 failures
```

## ユーザーの方針
- ログイン式にしない
- コンテナ管理不要
- 最新・トレンド技術を好む
- 破壊的操作は事前確認必須
- 会社アカウント (shota-kaseda / spice-factory) をこのプロジェクトで使わない
