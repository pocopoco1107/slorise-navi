# frozen_string_literal: true

class MachineGuideLink < ApplicationRecord
  belongs_to :machine_model

  enum :link_type, { analysis: 0, ceiling: 1, trophy: 2, other: 3 }
  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :url, presence: true, uniqueness: { scope: :machine_model_id }
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "は有効なURLを入力してください" }
  validates :source, presence: true

  scope :recent, -> { order(created_at: :desc) }

  # リンクタイプの日本語ラベル
  LINK_TYPE_LABELS = {
    "analysis" => "解析",
    "ceiling"  => "天井・期待値",
    "trophy"   => "トロフィー・設定判別",
    "other"    => "その他"
  }.freeze

  # リンクタイプのアイコン (Tailwindクラス)
  LINK_TYPE_BADGE = {
    "analysis" => { icon: "📊", bg: "bg-blue-50 text-blue-700 border-blue-200" },
    "ceiling"  => { icon: "🎯", bg: "bg-amber-50 text-amber-700 border-amber-200" },
    "trophy"   => { icon: "🏆", bg: "bg-purple-50 text-purple-700 border-purple-200" },
    "other"    => { icon: "📎", bg: "bg-gray-50 text-gray-600 border-gray-200" }
  }.freeze

  def link_type_label
    LINK_TYPE_LABELS[link_type] || "その他"
  end

  def link_type_icon
    LINK_TYPE_BADGE.dig(link_type, :icon) || "📎"
  end

  def link_type_badge_class
    LINK_TYPE_BADGE.dig(link_type, :bg) || "bg-gray-50 text-gray-600 border-gray-200"
  end
end
