# スロリセnavi ロードマップ

## 完了済み (Phase 1 MVP)
- [x] Rails 8 + Ruby 4.0.0 + PostgreSQL 17 セットアップ
- [x] 匿名Cookie投票 (Turbo Frame即時反映)
- [x] 47都道府県 + 15店舗 + 30機種 Seedデータ
- [x] 店舗詳細情報 (レート・換金率・台数・旧イベント日)
- [x] コメント・通報機能
- [x] ActiveAdmin管理画面
- [x] Rack::Attack レート制限
- [x] ホームページ (ヒーロー・統計・ランキング・使い方・都道府県)
- [x] SEO (meta-tags, sitemap, robots.txt, canonical)
- [x] セキュリティ (CSP, security headers, error pages)
- [x] 日本語ロケール (ja.yml)
- [x] RSpec テスト (19 examples)
- [x] CI (GitHub Actions)
- [x] Render.com デプロイ設定 (render.yaml)
- [x] GitHubリポジトリ (pocopoco1107/slorise-navi)

---

## Phase 2: コンテンツ充実 & 品質向上

### 2-1. データ拡充
- [ ] 店舗データ追加 (地元周辺20〜50店舗を手動登録)
- [ ] 機種マスタ更新 (最新機種の追加、古い機種のアーカイブ)
- [ ] AdminからのCSVインポート機能 (店舗・機種の一括登録)

### 2-2. UI/UX改善
- [ ] 投票後のフィードバックアニメーション (Stimulus)
- [ ] 設定分布の棒グラフ表示 (Chart.js or CSS)
- [ ] 店舗ページの機種フィルター/ソート機能
- [ ] お気に入り店舗 (Cookie保存、ログイン不要)
- [ ] ダークモード対応

### 2-3. テスト強化
- [ ] System Spec (Capybara + Playwright) で投票フロー E2Eテスト
- [ ] VoteSummary集計の境界値テスト
- [ ] Rack::Attackの統合テスト
- [ ] テストカバレッジ計測 (SimpleCov)

### 2-4. パフォーマンス
- [ ] N+1クエリ解消 (bullet gem導入)
- [ ] VoteSummary のキャッシュ戦略見直し
- [ ] ページネーション最適化

---

## Phase 3: デプロイ & 運用開始

### 3-1. デプロイ
- [ ] Render.comアカウント作成 & Blueprint デプロイ
- [ ] 独自ドメイン取得 & SSL設定
- [ ] RAILS_MASTER_KEY 環境変数設定

### 3-2. 運用ツール
- [ ] GA4導入 (Google Analytics)
- [ ] エラー監視 (Sentry or Honeybadger 無料枠)
- [ ] アップタイム監視 (UptimeRobot 無料枠)

### 3-3. 集客
- [ ] Twitter/Xパチスロ垢で毎日発信
- [ ] 自分の地元店舗に毎日投票 (アクティブ感維持)
- [ ] SEOロングテール: 「[店舗名] 設定」「[機種名] リセット」

---

## Phase 4: 成長機能

### 4-1. ユーザー参加型
- [ ] ユーザーによる店舗登録申請 (管理者承認制)
- [ ] 投票者ランキング・実績バッジ (投稿モチベーション)
- [ ] 店舗レビュー機能

### 4-2. データ自動取得
- [ ] Rakeタスク: P-WORLDから新台情報取得 (月次バッチ)
- [ ] 店舗の設置機種リスト取得

### 4-3. 通知・連携
- [ ] お気に入り店舗のメール/LINE通知
- [ ] イベント・取材情報カレンダー
- [ ] Discord/LINEコミュニティ連携

### 4-4. 収益化
- [ ] Google AdSense申請 (コンテンツ蓄積後)
- [ ] アフィリエイト (パチスロ攻略本・グッズ)
- [ ] プレミアム会員 (広告非表示・詳細統計) — PV安定後

---

## Phase 5: 拡張

- [ ] PWA対応 (ホーム画面追加)
- [ ] 位置情報で近くの店舗表示
- [ ] 機種別攻略ページ (天井・期待値)
- [ ] 過去データのトレンド分析 (週次・月次グラフ)
- [ ] APIエンドポイント公開 (サードパーティ連携)
