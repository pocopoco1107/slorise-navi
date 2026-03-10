# frozen_string_literal: true

# Extracts structured setting/trophy data from SnsReport raw text.
#
# Current implementation: rule-based pattern matching.
# Future: swap in Claude Haiku API for more accurate extraction.
#
# Usage:
#   parser = SnsParser.new(sns_report)
#   result = parser.parse!          # saves structured_data to report
#   result = parser.parse            # returns hash without saving
#
class SnsParser
  # Strategy interface — swap this class out for an API-based one later
  class RuleBasedStrategy
    TROPHY_PATTERNS = {
      "虹トロフィー"   => /虹\s*トロフィー/,
      "金トロフィー"   => /金\s*トロフィー/,
      "銀トロフィー"   => /銀\s*トロフィー/,
      "銅トロフィー"   => /銅\s*トロフィー/,
      "キリン柄"       => /キリン\s*柄/,
      "レインボー"     => /レインボー/,
      "エンディング"   => /エンディング/,
      "フリーズ"       => /フリーズ/,
      "プレミアム演出"  => /プレミアム\s*演出/
    }.freeze

    SETTING_PATTERNS = [
      { label: "6確定",   pattern: /設定\s*6\s*確定|設定6確/ },
      { label: "56確定",  pattern: /設定\s*[56]\s*(?:以上|確定)|[56]確定|設定56確定|設定5以上/ },
      { label: "456確定", pattern: /設定\s*4\s*以上|4以上確定|高設定確定|設定456/ },
      { label: "3以上",   pattern: /設定\s*3\s*以上/ },
      { label: "2以上",   pattern: /設定\s*2\s*以上/ },
      { label: "偶数確定", pattern: /偶数\s*確定|偶数設定確定/ },
      { label: "奇数確定", pattern: /奇数\s*確定|奇数設定確定/ }
    ].freeze

    CONFIDENCE_KEYWORDS = {
      high:   %w[確定 間違いない 100%],
      medium: %w[濃厚 示唆 期待],
      low:    %w[可能性 かも もしかして 噂]
    }.freeze

    def call(text)
      {
        trophies: extract_trophies(text),
        settings: extract_settings(text),
        confidence: estimate_confidence(text),
        keywords: extract_keywords(text)
      }
    end

    private

    def extract_trophies(text)
      TROPHY_PATTERNS.filter_map { |name, pat| name if text.match?(pat) }
    end

    def extract_settings(text)
      SETTING_PATTERNS.filter_map { |entry| entry[:label] if text.match?(entry[:pattern]) }
    end

    def estimate_confidence(text)
      CONFIDENCE_KEYWORDS.each do |level, words|
        return level.to_s if words.any? { |w| text.include?(w) }
      end
      "low"
    end

    def extract_keywords(text)
      all_keywords = %w[設定差 設定判別 示唆 確定演出 トロフィー エンディング フリーズ
                        高設定 低設定 据え置き リセット 朝一 ガックン]
      all_keywords.select { |kw| text.include?(kw) }
    end
  end

  attr_reader :report, :strategy

  def initialize(report, strategy: RuleBasedStrategy.new)
    @report = report
    @strategy = strategy
  end

  # Parse and return structured data hash (does not save)
  def parse
    text = "#{report.source_title} #{report.raw_text}"
    strategy.call(text)
  end

  # Parse, save to report.structured_data, and update trophy/setting/confidence fields
  def parse!
    result = parse

    attrs = { structured_data: result }

    # Update trophy_type from first detected trophy (if not already set)
    if report.trophy_type.blank? && result[:trophies].present?
      attrs[:trophy_type] = result[:trophies].first
    end

    # Update suggested_setting from first detected setting (if not already set)
    if report.suggested_setting.blank? && result[:settings].present?
      attrs[:suggested_setting] = result[:settings].first
    end

    # Update confidence (if currently unrated)
    if report.confidence_unrated?
      confidence_map = { "high" => :high, "medium" => :medium, "low" => :low }
      attrs[:confidence] = confidence_map[result[:confidence]] || :low
    end

    report.update!(attrs)
    result
  end
end
