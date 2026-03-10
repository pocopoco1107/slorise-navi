class Feedback < ApplicationRecord
  enum :category, { feature_request: 0, bug_report: 1, shop_request: 2, other: 3 }
  enum :status, { unread: 0, read: 1, resolved: 2 }, prefix: :feedback

  validates :body, presence: true, length: { maximum: 1000 }
  validates :category, presence: true
  validates :name, length: { maximum: 50 }, allow_blank: true
  validates :email, length: { maximum: 100 }, allow_blank: true

  CATEGORY_LABELS = {
    "feature_request" => "機能要望",
    "bug_report" => "不具合報告",
    "shop_request" => "店舗追加リクエスト",
    "other" => "その他"
  }.freeze

  def category_label
    CATEGORY_LABELS[category] || category
  end
end
