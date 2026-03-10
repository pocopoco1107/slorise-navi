class ShopReview < ApplicationRecord
  belongs_to :shop

  enum :category, {
    atmosphere: 0,  # 雰囲気
    service: 1,     # 接客
    equipment: 2,   # 設備
    payout: 3,      # 出玉
    access: 4       # アクセス
  }

  CATEGORY_LABELS = {
    "atmosphere" => "雰囲気",
    "service" => "接客",
    "equipment" => "設備",
    "payout" => "出玉",
    "access" => "アクセス"
  }.freeze

  validates :voter_token, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :title, length: { maximum: 50 }, allow_blank: true
  validates :body, presence: true, length: { maximum: 500 }
  validates :reviewer_name, length: { maximum: 20 }, allow_blank: true
  validates :voter_token, uniqueness: { scope: :shop_id, message: "この店舗にはすでにレビューを投稿しています" }

  has_many :reports, as: :reportable, dependent: :destroy

  scope :recent, -> { order(created_at: :desc) }

  def display_name
    reviewer_name.presence || "名無し"
  end

  def category_label
    CATEGORY_LABELS[category] || category
  end

  def self.average_rating_for(shop_id)
    where(shop_id: shop_id).average(:rating)&.round(1)
  end
end
