class MachineModel < ApplicationRecord
  enum :machine_type, { slot: 0, pachislot: 1 }
  enum :spec_type, { type_at: 0, type_art: 1, type_a_plus_at: 2, type_a: 3 }

  has_many :shop_machine_models, dependent: :destroy
  has_many :shops, through: :shop_machine_models
  has_many :votes, dependent: :destroy
  has_many :vote_summaries, dependent: :destroy
  has_many :sns_reports, dependent: :destroy
  has_many :machine_guide_links, dependent: :destroy

  scope :active, -> { where(active: true) }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # 表示用機種タイプ判定（名前ベース）
  DISPLAY_TYPES = {
    smart_slot: { label: "スマスロ", sort: 0, badge_class: "bg-violet-100 text-violet-700" },
    medal_at:   { label: "AT/ART",  sort: 1, badge_class: "bg-blue-100 text-blue-700" },
    a_type:     { label: "Aタイプ", sort: 2, badge_class: "bg-green-100 text-green-700" },
    other:      { label: "その他",  sort: 3, badge_class: "bg-gray-100 text-gray-600" }
  }.freeze

  def display_type
    @display_type ||= detect_display_type
  end

  def display_type_label
    DISPLAY_TYPES[display_type][:label]
  end

  def display_type_badge_class
    DISPLAY_TYPES[display_type][:badge_class]
  end

  def display_type_sort
    DISPLAY_TYPES[display_type][:sort]
  end

  # パチンコ機種の自動判定
  PACHINKO_PATTERNS = [
    /\AＰ/, /\AＣＲ/, /\Aｅ/,                          # 全角プレフィックス
    /\AP[^a-zA-Z0-9]/, /\APA/i, /\APF/i, /\ACR/i,     # 半角プレフィックス
    /\Ae[^a-df-zA-Z]/,                                  # 半角e + 非英字（eパチンコ）
    /\A‐Ｐ/,                                            # ダッシュ+Ｐ
    /\Aデカスタ/, /\Aスマパチ/, /\Aアマデジ/,            # パチンコ専用シリーズ
    /〜[廻回]る.*〜.*Ｐ/,                               # ヘソワイド系パチンコ
    /デジハネ/, /甘デジ/, /ぱちんこ/, /羽根モノ/          # キーワード
  ].freeze

  def self.pachinko_name?(name)
    PACHINKO_PATTERNS.any? { |pat| name.match?(pat) }
  end

  before_save :auto_deactivate_pachinko

  def to_param
    slug
  end

  # 号機区分バッジ表示用
  GENERATION_BADGE = {
    "6.5号機" => { label: "6.5号機", badge_class: "bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300" },
    "6号機"   => { label: "6号機",   badge_class: "bg-indigo-100 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300" },
    "5号機"   => { label: "5号機",   badge_class: "bg-teal-100 text-teal-700 dark:bg-teal-900/40 dark:text-teal-300" }
  }.freeze

  def generation_label
    generation.presence
  end

  def generation_badge_class
    GENERATION_BADGE.dig(generation, :badge_class) || "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300"
  end

  # 機械割の表示文字列 ("97.9% ~ 114.9%" / "97.9%" / nil)
  def payout_rate_display
    return nil if payout_rate_min.blank? && payout_rate_max.blank?
    if payout_rate_min.present? && payout_rate_max.present? && payout_rate_min != payout_rate_max
      "#{payout_rate_min}% ~ #{payout_rate_max}%"
    else
      "#{payout_rate_min || payout_rate_max}%"
    end
  end

  # 導入日 (released_onより優先、なければreleased_on)
  def effective_introduced_on
    introduced_on || released_on
  end

  # スマスロかどうか
  def smart_slot?
    display_type == :smart_slot
  end

  private

  # Aタイプ（ノーマルタイプ）の名前パターン
  A_TYPE_PATTERNS = [
    /ジャグラー/, /ハナハナ/, /ディスクアップ/, /ニューパルサー/, /バーサス/,
    /ゲッターマウス/, /クランキー/, /サンダー/, /花火/, /HANABI/,
    /スターパルサー/, /ハイハイシオサイ/, /ニューシオサイ/, /ビッグシオ/,
    /グランベルム/, /ドンちゃん/, /アレックス/, /ピエロ/,
    /ゴーゴージャック/, /チェリー/, /ファンキー(?!ドクター)/,
    /\AＡ/
  ].freeze

  def detect_display_type
    n = name
    if is_smart_slot? || generation&.include?("6.5号機") ||
       n.match?(/スマスロ/) || n.match?(/\AＬ/) || n.match?(/\AL[^a-z]/)
      :smart_slot
    elsif A_TYPE_PATTERNS.any? { |pat| n.match?(pat) } || spec_type == "type_a"
      :a_type
    elsif generation&.include?("6号機") || spec_type == "type_at" || spec_type == "type_art" ||
          spec_type == "type_a_plus_at" || n.match?(/\AＳ/) || n.match?(/\AS[^a-z]/)
      :medal_at
    else
      :other
    end
  end

  def auto_deactivate_pachinko
    self.active = false if self.class.pachinko_name?(name)
  end
end
