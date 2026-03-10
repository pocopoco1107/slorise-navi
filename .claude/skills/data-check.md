# data-check

Run a comprehensive data quality check for the スロリセnavi database. This skill checks for pachinko contamination, duplicate machines, and reports key metrics.

## Steps

1. Run the following rails runner commands sequentially and report results:

### パチンコ混入チェック
```bash
cd /Users/kasedashouta/Desktop/develop/slositte && export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH" && bin/rails runner '
pachinko_patterns = MachineModel.active.where(
  "name ~ E'"'"'^\u{FF30}'"'"' OR name ~ E'"'"'^\u{FF23}\u{FF32}'"'"' OR name ~ E'"'"'^\u{FF45}'"'"' OR name LIKE '"'"'%ぱちんこ%'"'"' OR name LIKE '"'"'%デジハネ%'"'"' OR name LIKE '"'"'%甘デジ%'"'"' OR name LIKE '"'"'%羽根モノ%'"'"'"
)
half_width = MachineModel.active.where("name ~ E'"'"'^PA[^a-z]'"'"' OR name ~ E'"'"'^P\\s'"'"' OR name ~ E'"'"'^PF[^a-z]'"'"' OR name ~ E'"'"'^CR'"'"'")
count = pachinko_patterns.count + half_width.count
puts "=== パチンコ混入チェック ==="
if count == 0
  puts "OK: パチンコ機種の混入なし"
else
  puts "NG: #{count}件のパチンコ機種が混入"
  (pachinko_patterns.limit(5).pluck(:name) + half_width.limit(5).pluck(:name)).each { |n| puts "  - #{n}" }
end
'
```

### 重複チェック
```bash
bin/rails runner '
names = MachineModel.active.pluck(:id, :name)
normalized = names.group_by { |_, n| n.unicode_normalize(:nfkc).strip }
dups = normalized.select { |_, v| v.size > 1 }
puts "=== 全角/半角重複チェック ==="
if dups.empty?
  puts "OK: 重複なし"
else
  puts "NG: #{dups.count}件の重複"
  dups.first(5).each { |norm, items| puts "  #{norm}: #{items.map(&:last).join('" / "')}" }
end
'
```

### 件数サマリ
```bash
bin/rails runner '
puts "=== データ件数サマリ ==="
shops = Shop.count
active = MachineModel.active.count
popular = MachineModel.active.joins(:shop_machine_models).group("machine_models.id").having("COUNT(*) >= 3").count.size
links = ShopMachineModel.count
rate_count = Shop.where.not(slot_rates: [nil, ""]).count
facility_count = Shop.where.not(notes: [nil, ""]).count
puts "店舗: #{shops}"
puts "アクティブ機種: #{active}"
puts "3店舗以上設置: #{popular}"
puts "店舗×機種リンク: #{links}"
puts "レート情報: #{rate_count}/#{shops} (#{(rate_count.to_f/shops*100).round(1)}%)"
puts "設備情報: #{facility_count}/#{shops} (#{(facility_count.to_f/shops*100).round(1)}%)"
puts "今日の投票数: #{Vote.where(voted_on: Date.current).count}"
puts "累計投票数: #{Vote.count}"
'
```

2. Present results in a clear summary table
3. Flag any issues found and suggest fixes
