# pworld-scrape

P-WORLDからデータを取得するスクレイピングタスクを実行する。

## 前提知識
- P-WORLD (p-world.co.jp) はEUC-JPエンコーディング
- WebFetchは使えない（404になる）→ Net::HTTP + `rails runner` を使う
- レート制限: sleep 2.5秒/リクエスト
- パチンコフィルタは必ず適用する（memory/scraping.md 参照）

## 利用可能なRakeタスク
```bash
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

# 店舗インポート（全国一括）
bundle exec rake pworld:import_shops

# 特定都道府県の機種リンク
bundle exec rake pworld:import_shop_machines_by_pref[tokyo]

# 全国機種リンク（ブロック並列）
bundle exec rake pworld:import_all_shop_machines
```

## 実行後の必須手順
1. `/data-check` スキルを実行してデータ品質確認
2. パチンコ混入があれば即座にクリーニング
3. 重複があれば NFKC正規化で統合
4. 結果をユーザーに報告

## カスタムスクレイピング（新規データ取得時）
`rails runner` で Net::HTTP を使用:
```ruby
require 'net/http'
require 'uri'
uri = URI.parse(url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
req = Net::HTTP::Get.new(uri.request_uri)
req['User-Agent'] = 'Mozilla/5.0 ...'
res = http.request(req)
body = res.body.force_encoding(Encoding::EUC_JP).encode('UTF-8', invalid: :replace, undef: :replace)
doc = Nokogiri::HTML(body)
sleep 2.5
```
