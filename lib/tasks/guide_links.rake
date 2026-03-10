# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

namespace :pworld do
  desc "Google Custom Search APIで機種攻略リンクを収集"
  task :collect_guide_links, [:limit] => :environment do |_task, args|
    $stdout.sync = true

    api_key = ENV["GOOGLE_CSE_API_KEY"]
    cse_id  = ENV["GOOGLE_CSE_ID"]

    unless api_key.present? && cse_id.present?
      puts "⚠ GOOGLE_CSE_API_KEY / GOOGLE_CSE_ID が未設定です。スキップします。"
      puts "  export GOOGLE_CSE_API_KEY=your_key"
      puts "  export GOOGLE_CSE_ID=your_cse_id"
      next
    end

    dry_run = ENV["DRY_RUN"] == "1"
    puts "🔍 DRY RUN モード（保存しません）" if dry_run

    limit = (args[:limit] || 50).to_i
    machines = MachineModel.active.order(:name).limit(limit)

    puts "対象機種: #{machines.count}件 (limit=#{limit})"

    # 信頼サイトのドメイン → source名マッピング
    trusted_sites = GuideLinksCollector::TRUSTED_SITES

    total_created = 0
    total_skipped = 0

    machines.each_with_index do |machine, idx|
      puts "#{idx + 1}/#{machines.count} #{machine.name}"

      GuideLinksCollector::SEARCH_QUERIES.each do |query_template, link_type|
        query = query_template.gsub("{name}", machine.name)
        results = GuideLinksCollector.google_search(query, api_key, cse_id)

        results.each do |item|
          url = item["link"]
          title = item["title"]
          domain = URI.parse(url).host rescue nil
          next unless domain

          # 信頼サイトのみ
          site_key = trusted_sites.keys.find { |d| domain.include?(d) }
          next unless site_key

          source_name = trusted_sites[site_key]

          if dry_run
            puts "  [DRY] #{link_type}: #{source_name} - #{title}"
            puts "        #{url}"
            total_created += 1
          else
            link = MachineGuideLink.find_or_initialize_by(
              machine_model: machine,
              url: url
            )
            if link.new_record?
              link.assign_attributes(
                title: title&.truncate(255),
                source: source_name,
                link_type: link_type,
                status: :pending
              )
              if link.save
                total_created += 1
                puts "  + #{link_type}: #{source_name} - #{title}"
              else
                puts "  ! 保存エラー: #{link.errors.full_messages.join(', ')}"
              end
            else
              total_skipped += 1
            end
          end
        end

        sleep 1 # API rate limit対策
      end
    end

    puts "\n完了: 新規#{total_created}件, スキップ#{total_skipped}件"
  end
end

# Google Custom Search ヘルパー
module GuideLinksCollector
  # 信頼サイトのドメイン => 表示名
  TRUSTED_SITES = {
    "chonborista.com"      => "ちょんぼりすた",
    "slopachi-quest.com"   => "すろぱちくえすと",
    "nana-press.com"       => "なな徹",
    "slotjin.com"          => "スロットジン",
    "pachislot-navi.com"   => "パチスロナビ",
    "p-town.dmm.com"       => "DMMぱちタウン",
    "game8.jp"             => "Game8",
    "slot-expectation.com" => "スロット期待値見える化"
  }.freeze

  # 検索クエリ => link_type
  SEARCH_QUERIES = {
    "{name} 天井 期待値"  => :ceiling,
    "{name} 設定判別"     => :trophy,
    "{name} 解析 まとめ"  => :analysis
  }.freeze

  def self.google_search(query, api_key, cse_id)
    uri = URI("https://www.googleapis.com/customsearch/v1")
    uri.query = URI.encode_www_form(
      key: api_key,
      cx: cse_id,
      q: query,
      num: 5,
      lr: "lang_ja"
    )

    response = Net::HTTP.get_response(uri)

    if response.code == "200"
      data = JSON.parse(response.body)
      data["items"] || []
    else
      puts "  ⚠ API Error (#{response.code}): #{response.body.truncate(200)}"
      []
    end
  rescue StandardError => e
    puts "  ⚠ リクエストエラー: #{e.message}"
    []
  end
end
